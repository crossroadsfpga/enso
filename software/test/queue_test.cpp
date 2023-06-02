/*
 * Copyright (c) 2023, Carnegie Mellon University
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 *
 *      * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *      * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      * Neither the name of the copyright holder nor the names of its
 *      contributors may be used to endorse or promote products derived from
 *      this software without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <enso/queue.h>
#include <gtest/gtest.h>

#include <array>
#include <cstdint>

TEST(TestQueue, CreateProducer) {
  auto q = enso::QueueProducer<int>::Create("CreateProducer");
  EXPECT_NE(q, nullptr);
}

TEST(TestQueue, CreateConsumer) {
  auto q = enso::QueueConsumer<int>::Create("CreateConsumer");
  EXPECT_NE(q, nullptr);
}

TEST(TestQueue, CreateProducerConsumer) {
  auto q_prod = enso::QueueProducer<int>::Create("CreateProducerConsumer");
  EXPECT_NE(q_prod, nullptr);

  auto q_cons = enso::QueueConsumer<int>::Create("CreateProducerConsumer");
  EXPECT_NE(q_cons, nullptr);
}

TEST(TestQueue, CreateConsumerProducer) {
  auto q_cons = enso::QueueConsumer<int>::Create("CreateConsumerProducer");
  EXPECT_NE(q_cons, nullptr);

  auto q_prod = enso::QueueProducer<int>::Create("CreateConsumerProducer");
  EXPECT_NE(q_prod, nullptr);
}

TEST(TestQueue, PushPop) {
  auto q_prod = enso::QueueProducer<int>::Create("PushPop");
  EXPECT_NE(q_prod, nullptr);

  auto q_cons = enso::QueueConsumer<int>::Create("PushPop");
  EXPECT_NE(q_cons, nullptr);

  EXPECT_EQ(q_prod->Push(42), 0);
  EXPECT_EQ(q_prod->Push(43), 0);

  EXPECT_EQ(q_cons->Pop().value_or(-1), 42);
  EXPECT_EQ(q_cons->Pop().value_or(-1), 43);
  EXPECT_EQ(q_cons->Pop().value_or(-1), -1);
}

TEST(TestQueue, QueueEmpty) {
  auto q_cons = enso::QueueConsumer<int>::Create("QueueEmpty");
  EXPECT_NE(q_cons, nullptr);
  EXPECT_EQ(q_cons->Pop().value_or(-1), -1);
}

TEST(TestQueue, QueueFull) {
  auto q_prod =
      enso::QueueProducer<int>::Create("QueueFull", enso::kBufPageSize);
  EXPECT_NE(q_prod, nullptr);

  uint32_t capacity = enso::kBufPageSize / enso::kCacheLineSize;
  EXPECT_EQ(q_prod->capacity(), capacity);

  for (uint32_t i = 0; i < capacity; ++i) {
    EXPECT_EQ(q_prod->Push(i), 0);
  }

  EXPECT_EQ(q_prod->Push(42), -1);
}

TEST(TestQueue, EmptyAfterFull) {
  using elem_t = std::array<int32_t, 2 * enso::kCacheLineSize / 4>;
  auto q_prod =
      enso::QueueProducer<elem_t>::Create("EmptyAfterFull", enso::kBufPageSize);
  EXPECT_NE(q_prod, nullptr);

  auto q_cons = enso::QueueConsumer<elem_t>::Create("EmptyAfterFull");
  EXPECT_NE(q_cons, nullptr);

  int32_t capacity = enso::kBufPageSize / enso::kCacheLineSize / 4;
  EXPECT_EQ(q_prod->capacity(), capacity);

  elem_t elem;
  for (int32_t i = 0; i < capacity; ++i) {
    elem[0] = i;
    EXPECT_EQ(q_prod->Push(elem), 0);
  }
  elem[0] = -1;
  EXPECT_EQ(q_prod->Push(elem), -1);

  for (int32_t i = 0; i < capacity; ++i) {
    EXPECT_EQ(q_cons->Pop().value_or(elem)[0], i);
  }
  EXPECT_EQ(q_cons->Pop().value_or(elem)[0], -1);
}

TEST(TestQueue, Front) {
  auto q_prod = enso::QueueProducer<int>::Create("Front");
  EXPECT_NE(q_prod, nullptr);

  auto q_cons = enso::QueueConsumer<int>::Create("Front");
  EXPECT_NE(q_cons, nullptr);

  EXPECT_EQ(q_prod->Push(42), 0);
  EXPECT_EQ(q_prod->Push(43), 0);

  EXPECT_EQ(*q_cons->Front(), 42);
  EXPECT_EQ(q_cons->Pop().value_or(-1), 42);
  EXPECT_EQ(*q_cons->Front(), 43);
  EXPECT_EQ(q_cons->Pop().value_or(-1), 43);
  EXPECT_EQ(q_cons->Front(), nullptr);
}

TEST(TestQueue, TestWrapAround) {
  using elem_t = std::array<int32_t, 2 * enso::kCacheLineSize / 4>;
  auto q_prod =
      enso::QueueProducer<elem_t>::Create("TestWrapAround", enso::kBufPageSize);
  EXPECT_NE(q_prod, nullptr);

  auto q_cons = enso::QueueConsumer<elem_t>::Create("TestWrapAround");
  EXPECT_NE(q_cons, nullptr);

  elem_t elem;
  int32_t i = 0;
  for (; i < static_cast<int32_t>(q_prod->capacity()) / 2; ++i) {
    elem.fill(i);
    EXPECT_EQ(q_prod->Push(elem), 0);
  }

  int32_t j = 0;
  for (; j < 2; ++j) {
    EXPECT_EQ(q_cons->Pop().value_or(elem)[0], j);
  }

  for (; i < static_cast<int32_t>(q_prod->capacity()) + j; ++i) {
    elem.fill(i);
    EXPECT_EQ(q_prod->Push(elem), 0);
  }
  elem[0] = -1;
  EXPECT_EQ(q_prod->Push(elem), -1);

  for (; j < i; ++j) {
    EXPECT_EQ(q_cons->Pop().value_or(elem)[0], j);
  }

  EXPECT_EQ(q_cons->Pop().value_or(elem)[0], -1);
}
