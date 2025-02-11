// ====---------- math-bf16-conv.cu---------- *- CUDA -* ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//
// ===---------------------------------------------------------------------===//

#include <iomanip>
#include <iostream>
#include <vector>

#include "cuda_bf16.h"

using namespace std;

typedef pair<float2, int> f2i_pair;
typedef pair<float, int> fi_pair;
typedef pair<__nv_bfloat162, int> bf162i_pair;
typedef pair<__nv_bfloat16, int> bf16i_pair;

int passed = 0;
int failed = 0;

void check(bool IsPassed) {
  if (IsPassed) {
    cout << " ---- passed" << endl;
    passed++;
  } else {
    cout << " ---- failed" << endl;
    failed++;
  }
}

void checkResult(const string &FuncName, const vector<float> &Inputs,
                 const float &Expect, const float &Result,
                 const int precision) {
  cout << FuncName << "(" << Inputs[0] << "";
  for (size_t i = 1; i < Inputs.size(); ++i) {
    cout << ", " << Inputs[i];
  }
  cout << ") = " << fixed << setprecision(precision) << Result << " (expect "
       << Expect - pow(10, -precision) << " ~ " << Expect + pow(10, -precision)
       << ")";
  cout.unsetf(ios::fixed);
  check(abs(Result - Expect) < pow(10, -precision));
}

void checkResult(const string &FuncName, const vector<float2> &Inputs,
                 const float2 &Expect, const float2 &Result,
                 const int precision) {
  cout << FuncName << "({" << Inputs[0].x << ", " << Inputs[0].y << "}";
  for (size_t i = 1; i < Inputs.size(); ++i) {
    cout << ", {" << Inputs[i].x << ", " << Inputs[i].y << "}";
  }
  cout << ") = " << fixed << setprecision(precision) << "{" << Result.x << ", "
       << Result.y << "} (expect {" << Expect.x - pow(10, -precision) << " ~ "
       << Expect.x + pow(10, -precision) << ", "
       << Expect.y - pow(10, -precision) << " ~ "
       << Expect.y + pow(10, -precision) << ")";
  cout.unsetf(ios::fixed);
  check(abs(Result.x - Expect.x) < pow(10, -precision) &&
        abs(Result.y - Expect.y) < pow(10, -precision));
}

void checkResult(const string &FuncName, const vector<__nv_bfloat16> &Inputs,
                 const __nv_bfloat16 &Expect, const float &Result,
                 const int precision) {
  vector<float> FInputs;
  for (const auto &it : Inputs) {
    FInputs.push_back(__bfloat162float(it));
  }
  float FExpect = __bfloat162float(Expect);
  checkResult(FuncName, FInputs, FExpect, Result, precision);
}

void checkResult(const string &FuncName, const vector<__nv_bfloat162> &Inputs,
                 const float2 &Expect, const float2 &Result,
                 const int precision) {
  vector<float2> FInputs;
  for (const auto &it : Inputs) {
    FInputs.push_back({__bfloat162float(it.x), __bfloat162float(it.y)});
  }
  checkResult(FuncName, FInputs, Expect, Result, precision);
}

void checkResult(const string &FuncName, const vector<float2> &Inputs,
                 const __nv_bfloat162 &Expect, const float2 &Result,
                 const int precision) {
  float2 FExpect{__bfloat162float(Expect.x), __bfloat162float(Expect.y)};
  checkResult(FuncName, Inputs, FExpect, Result, precision);
}

void checkResult(const string &FuncName, const vector<__nv_bfloat162> &Inputs,
                 const __nv_bfloat162 &Expect, const float2 &Result,
                 const int precision) {
  vector<float2> FInputs;
  for (const auto &it : Inputs) {
    FInputs.push_back({__bfloat162float(it.x), __bfloat162float(it.y)});
  }
  checkResult(FuncName, FInputs, Expect, Result, precision);
}

__global__ void setValue(__nv_bfloat16 *Input1, const __nv_bfloat16 Input2) {
  *Input1 = Input2;
}

__global__ void setValue(__nv_bfloat162 *Input1, const __nv_bfloat162 Input2) {
  *Input1 = Input2;
}

__global__ void bFloat1622float2(float *const Result, __nv_bfloat162 Input1) {
  auto ret = __bfloat1622float2(Input1);
  Result[0] = ret.x;
  Result[1] = ret.y;
}

void testBFloat1622float2Cases(
    const vector<pair<__nv_bfloat162, f2i_pair>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    bFloat1622float2<<<1, 1>>>(Result, TestCase.first);
    cudaDeviceSynchronize();
    checkResult("__bfloat1622float2", {TestCase.first}, TestCase.second.first,
                {Result[0], Result[1]}, TestCase.second.second);
    auto ret = __bfloat1622float2(TestCase.first);
    Result[0] = ret.x;
    Result[1] = ret.y;
    checkResult("(host)__bfloat1622float2", {TestCase.first},
                TestCase.second.first, {Result[0], Result[1]},
                TestCase.second.second);
  }
}

__global__ void bFloat162float(float *const Result, __nv_bfloat16 Input1) {
  *Result = __bfloat162float(Input1);
}

void testBFloat162floatCases(
    const vector<pair<__nv_bfloat16, fi_pair>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    bFloat162float<<<1, 1>>>(Result, TestCase.first);
    cudaDeviceSynchronize();
    checkResult("__bfloat162float", {TestCase.first}, TestCase.second.first,
                *Result, TestCase.second.second);
    *Result = __bfloat162float(TestCase.first);
    checkResult("(host)__bfloat162float", {TestCase.first},
                TestCase.second.first, *Result, TestCase.second.second);
  }
}

__global__ void float22bFloat162_rn(float *const Result, float2 Input1) {
  auto ret = __float22bfloat162_rn(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testFloat22bFloat162_rnCases(
    const vector<pair<float2, bf162i_pair>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    float22bFloat162_rn<<<1, 1>>>(Result, TestCase.first);
    cudaDeviceSynchronize();
    checkResult("__float22bfloat162_rn", {TestCase.first},
                TestCase.second.first, {Result[0], Result[1]},
                TestCase.second.second);
    auto ret = __float22bfloat162_rn(TestCase.first);
    Result[0] = __bfloat162float(ret.x);
    Result[1] = __bfloat162float(ret.y);
    checkResult("(host)__float22bfloat162_rn", {TestCase.first},
                TestCase.second.first, {Result[0], Result[1]},
                TestCase.second.second);
  }
}

__global__ void float2bFloat16(float *const Result, float Input1) {
  *Result = __bfloat162float(__float2bfloat16(Input1));
}

void testFloat2bFloat16Cases(const vector<pair<float, bf16i_pair>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    float2bFloat16<<<1, 1>>>(Result, TestCase.first);
    cudaDeviceSynchronize();
    checkResult("__float2bfloat16", {TestCase.first}, TestCase.second.first,
                *Result, TestCase.second.second);
    *Result = __float2bfloat16(TestCase.first);
    checkResult("(host)__float2bfloat16", {TestCase.first},
                TestCase.second.first, *Result, TestCase.second.second);
  }
}

__global__ void ldca(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldca(Input1);
}

void testLdcaCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldca<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldca", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldca(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldca(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdcaCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldca<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldca", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void ldcg(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldcg(Input1);
}

void testLdcgCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcg<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcg", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldcg(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldcg(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdcgCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcg<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcg", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void ldcs(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldcs(Input1);
}

void testLdcsCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcs<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcs", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldcs(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldcs(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdcsCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcs<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcs", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void ldcv(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldcv(Input1);
}

void testLdcvCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcv<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcv", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldcv(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldcv(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdcvCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldcv<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldcv", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void ldg(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldg(Input1);
}

void testLdgCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldg<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldg", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldg(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldg(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdgCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldg<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldg", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void ldlu(float *const Result, __nv_bfloat16 *Input1) {
  *Result = __ldlu(Input1);
}

void testLdluCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat16 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldlu<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldlu", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void ldlu(float *const Result, __nv_bfloat162 *Input1) {
  auto ret = __ldlu(Input1);
  Result[0] = __bfloat162float(ret.x);
  Result[1] = __bfloat162float(ret.y);
}

void testLdluCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  for (const auto &TestCase : TestCases) {
    __nv_bfloat162 *Input;
    cudaMallocManaged(&Input, sizeof(*Input));
    setValue<<<1, 1>>>(Input, TestCase.first);
    cudaDeviceSynchronize();
    ldlu<<<1, 1>>>(Result, Input);
    cudaDeviceSynchronize();
    checkResult("__ldlu", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void stcg(float *const Result, __nv_bfloat16 Input1,
                     __nv_bfloat16 *const Temp) {
  __stcg(Temp, Input1);
  *Result = __bfloat162float(*Temp);
}

void testStcgCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  __nv_bfloat16 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stcg<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stcg", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void stcg(float *const Result, __nv_bfloat162 Input1,
                     __nv_bfloat162 *const Temp) {
  __stcg(Temp, Input1);
  Result[0] = __bfloat162float(Temp->x);
  Result[1] = __bfloat162float(Temp->y);
}

void testStcgCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  __nv_bfloat162 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stcg<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stcg", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void stcs(float *const Result, __nv_bfloat16 Input1,
                     __nv_bfloat16 *const Temp) {
  __stcs(Temp, Input1);
  *Result = __bfloat162float(*Temp);
}

void testStcsCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  __nv_bfloat16 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stcs<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stcs", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void stcs(float *const Result, __nv_bfloat162 Input1,
                     __nv_bfloat162 *const Temp) {
  __stcs(Temp, Input1);
  Result[0] = __bfloat162float(Temp->x);
  Result[1] = __bfloat162float(Temp->y);
}

void testStcsCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  __nv_bfloat162 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stcs<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stcs", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void stwb(float *const Result, __nv_bfloat16 Input1,
                     __nv_bfloat16 *const Temp) {
  __stwb(Temp, Input1);
  *Result = __bfloat162float(*Temp);
}

void testStwbCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  __nv_bfloat16 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stwb<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stwb", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void stwb(float *const Result, __nv_bfloat162 Input1,
                     __nv_bfloat162 *const Temp) {
  __stwb(Temp, Input1);
  Result[0] = __bfloat162float(Temp->x);
  Result[1] = __bfloat162float(Temp->y);
}

void testStwbCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  __nv_bfloat162 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stwb<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stwb", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

__global__ void stwt(float *const Result, __nv_bfloat16 Input1,
                     __nv_bfloat16 *const Temp) {
  __stwt(Temp, Input1);
  *Result = __bfloat162float(*Temp);
}

void testStwtCases(const vector<pair<__nv_bfloat16, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, sizeof(*Result));
  __nv_bfloat16 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stwt<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stwt", {TestCase.first}, TestCase.first, *Result,
                TestCase.second);
  }
}

__global__ void stwt(float *const Result, __nv_bfloat162 Input1,
                     __nv_bfloat162 *const Temp) {
  __stwt(Temp, Input1);
  Result[0] = __bfloat162float(Temp->x);
  Result[1] = __bfloat162float(Temp->y);
}

void testStwtCases(const vector<pair<__nv_bfloat162, int>> &TestCases) {
  float *Result;
  cudaMallocManaged(&Result, 2 * sizeof(*Result));
  __nv_bfloat162 *Temp;
  cudaMallocManaged(&Temp, sizeof(*Temp));
  for (const auto &TestCase : TestCases) {
    stwt<<<1, 1>>>(Result, TestCase.first, Temp);
    cudaDeviceSynchronize();
    checkResult("__stwt", {TestCase.first}, TestCase.first,
                {Result[0], Result[1]}, TestCase.second);
  }
}

int main() {
  testBFloat1622float2Cases({
      {{-0.3, -0.5}, {{-0.30078125, -0.5}, 16}},
      {{0.3, 0.5}, {{0.30078125, 0.5}, 16}},
      {{30, 50}, {{30, 50}, 14}},
      {{0.432643, 0.23654}, {{0.43359375, 0.236328125}, 16}},
  });
  testBFloat162floatCases({
      {-0.3, {-0.30078125, 16}},
      {0.3, {0.30078125, 16}},
      {30, {30, 14}},
      {0.432643, {0.43359375, 16}},
  });
  testFloat22bFloat162_rnCases({
      {{-0.3, -0.5}, {{-0.30078125, -0.5}, 16}},
      {{0.3, 0.5}, {{0.30078125, 0.5}, 16}},
      {{30, 50}, {{30, 50}, 14}},
      {{0.432643, 0.23654}, {{0.43359375, 0.236328125}, 16}},
  });
  testFloat2bFloat16Cases({
      {-0.3, {-0.30078125, 16}},
      {0.3, {0.30078125, 16}},
      {30, {30, 14}},
      {0.432643, {0.43359375, 16}},
  });
  testLdcaCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdcaCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testLdcgCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdcgCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testLdcsCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdcsCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testLdcvCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdcvCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testLdgCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdgCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testLdluCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testLdluCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testStcgCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testStcgCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testStcsCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testStcsCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testStwbCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testStwbCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  testStwtCases({
      {-0.3, 16},
      {-0.4, 16},
      {0, 37},
      {0.7, 16},
      {1, 15},
      {100.6, 14},
  });
  testStwtCases({
      {{-0.3, -0.4}, 16},
      {{0, 0.7}, 16},
      {{1, 100.6}, 14},
      {{100.6, 1}, 14},
  });
  cout << "passed " << passed << "/" << passed + failed << " cases!" << endl;
  if (failed) {
    cout << "failed!" << endl;
  }
  return failed;
}
