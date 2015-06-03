#include <thread>
#include <immintrin.h>
#include <atomic>
#include "modelHandler.hpp"
#include "common.hpp"
#include "sec.hpp"

#include "modelHandler_avx_func.hpp"

namespace w2xc {
void
filter_AVX_impl(const float *packed_input,
		float *packed_output,
		int nInputPlanes,
		int nOutputPlanes,
		const float *fbiases,
		const float *weight,
		cv::Size ipSize,
		int nJob)
{
	filter_AVX_impl0<false>(packed_input,
				packed_output,
				nInputPlanes,
				nOutputPlanes,
				fbiases,
				weight,
				ipSize,
				nJob);
}


}