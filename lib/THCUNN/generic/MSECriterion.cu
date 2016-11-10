#ifndef THC_GENERIC_FILE
#define THC_GENERIC_FILE "generic/MSECriterion.cu"
#else

void THNN_(MSECriterion_updateOutput)(
           THCState *state,
           THCTensor *input,
           THCTensor *target,
           THCTensor *output,
           bool sizeAverage)
{
  THCUNN_assertSameGPU_generic(state, 2, input, target);
  THArgCheck(THCTensor_(nElement)(state, input) == THCTensor_(nElement)(state, target), 2,
    "input and target need to have the same number of elements"
  );

  long size = THCTensor_(nElement)(state, input);

  input = THCTensor_(newContiguous)(state, input);
  target = THCTensor_(newContiguous)(state, target);

  thrust::device_ptr<real> input_data(THCTensor_(data)(state, input));
  thrust::device_ptr<real> target_data(THCTensor_(data)(state, target));
  accreal sum = thrust::inner_product(
#if CUDA_VERSION >= 7000
    thrust::cuda::par.on(THCState_getCurrentStream(state)),
#endif
    input_data, input_data+size, target_data, (accreal) 0,
    thrust::plus<accreal>(), mse_functor<real, accreal>());

  if (sizeAverage)
    sum /= size;

  THCTensor_(free)(state, input);
  THCTensor_(free)(state, target);

  THCTensor_(set1d)(state, output, 0, ScalarConvert<accreal, real>::to(sum));
}

void THNN_(MSECriterion_updateGradInput)(
           THCState *state,
           THCTensor *input,
           THCTensor *target,
           THCTensor *gradInput,
           bool sizeAverage)
{
  THCUNN_assertSameGPU_generic(state, 3, input, target, gradInput);
  THArgCheck(THCTensor_(nElement)(state, input) == THCTensor_(nElement)(state, target), 2,
    "input and target need to have the same number of elements"
  );

  long size = THCTensor_(nElement)(state, input);
  accreal norm = sizeAverage ? (accreal)(2)/size : (accreal)(2);

  input = THCTensor_(newContiguous)(state, input);
  target = THCTensor_(newContiguous)(state, target);

  THCTensor_(resizeAs)(state, gradInput, input);

  thrust::device_ptr<real> input_data(THCTensor_(data)(state, input));
  thrust::device_ptr<real> target_data(THCTensor_(data)(state, target));
  thrust::device_ptr<real> gradInput_data(THCTensor_(data)(state, gradInput));

  thrust::transform(
#if CUDA_VERSION >= 7000
    thrust::cuda::par.on(THCState_getCurrentStream(state)),
#endif
    input_data, input_data+size, target_data, gradInput_data,
    mse_updateGradInput_functor<real, accreal>(norm));

  THCTensor_(free)(state, input);
  THCTensor_(free)(state, target);
}

#endif