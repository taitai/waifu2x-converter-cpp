/* -*- mode: c -*- */

float
get_data(__global const float *p, int hsz, int wsz, int step, int yi, int xi, int num_plane, int plane)
{
    xi = min(wsz-1, xi);
    xi = max(0, xi);

    return p[xi * num_plane];
}

__kernel void
filter(__global const float * __restrict__ packed_input,
       int nInputPlanes,
       __global float * __restrict__ packed_output,
       int nOutputPlanes,
       __global float * __restrict__ biases,
       unsigned int hsz,
       unsigned int wsz,
       __global float * __restrict__ weight,
       __local float * __restrict__ intermediate)
{
    unsigned int yi = get_group_id(1);
    unsigned int xi = get_group_id(0);

    unsigned int lid = get_local_id(0);

    __global const float * __restrict__ in = packed_input;
    size_t in_step = wsz * sizeof(float) * nInputPlanes;

    __global char *inp = (__global char*)packed_input;

    inp += in_step*yi;
    __global char *in0p = inp - in_step;
    if (yi == 0) {
        in0p = inp;
    }

    __global char *in1p = inp;
    __global char *in2p = inp + in_step;

    if (yi == hsz-1) {
        in2p = inp;
    }

    __global float *in01 = (__global float*)in0p;
    __global float *in11 = (__global float*)in1p;
    __global float *in21 = (__global float*)in2p;

    in01 += xi * nInputPlanes;
    in11 += xi * nInputPlanes;
    in21 += xi * nInputPlanes;

    for (int ipIndex = 0; ipIndex < nInputPlanes; ipIndex++) {
        float i00, i01, i02;
        float i10, i11, i12;
        float i20, i21, i22;

        i01 = in01[0];
        i11 = in11[0];
        i21 = in21[0];

        if (xi == 0) {
            i00 = i01;
            i10 = i11;
            i20 = i21;
        } else {
            i00 = in01[-nInputPlanes];
            i10 = in11[-nInputPlanes];
            i20 = in21[-nInputPlanes];
        }

        if (xi == wsz-1) {
            i02 = i01;
            i12 = i11;
            i22 = i21;
        } else {
            i02 = in01[+nInputPlanes];
            i12 = in11[+nInputPlanes];
            i22 = in21[+nInputPlanes];
        }

        in01 ++;
        in11 ++;
        in21 ++;

        __global float *w = weight + (ipIndex * nOutputPlanes) * 9 + lid;

        for (unsigned int opIndex_base = 0;
             opIndex_base < (unsigned int)nOutputPlanes;
             opIndex_base += VEC_WIDTH)
        {
            int opIndex = opIndex_base + lid;

            int oi_0 = lid;
            int oi_1 = opIndex_base;

            float v = 0;

            v += w[0*VEC_WIDTH] * i00;
            v += w[1*VEC_WIDTH] * i01;
            v += w[2*VEC_WIDTH] * i02;

            v += w[3*VEC_WIDTH] * i10;
            v += w[4*VEC_WIDTH] * i11;
            v += w[5*VEC_WIDTH] * i12;

            v += w[6*VEC_WIDTH] * i20;
            v += w[7*VEC_WIDTH] * i21;
            v += w[8*VEC_WIDTH] * i22;

            w += 9 * VEC_WIDTH;

            if (ipIndex == 0) {
                intermediate[opIndex] = v;
            } else {
                intermediate[opIndex] += v;
            }
        }
    }

    __global float *out = packed_output + (yi*wsz + xi)*nOutputPlanes;

    for (unsigned int opIndex_base = 0;
         opIndex_base < nOutputPlanes;
         opIndex_base+=VEC_WIDTH)
    {
        unsigned int opIndex = opIndex_base + lid;
        float bv = biases[opIndex];
        float v = intermediate[opIndex];
        v += bv;

        float mtz = max(v, 0.0f);
        float ltz = min(v, 0.0f);

        v = ltz * 0.1f + mtz;

        out[opIndex] = v;
    }
}
