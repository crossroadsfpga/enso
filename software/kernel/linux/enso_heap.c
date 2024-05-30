/*
 * Copyright (c) 2024, Carnegie Mellon University
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
#include "enso_heap.h"

int parent(int index) { return (index - 1) / 2; }

int left(int index) { return (2 * index) + 1; }

int right(int index) { return (2 * index) + 2; }

void init_heap(struct min_heap *heap) {
  heap->capacity = HEAP_SIZE;
  heap->harr = kzalloc(heap->capacity * sizeof(struct heap_node), GFP_KERNEL);
  if (heap->harr == NULL) {
    printk("couldn't create the heap\n");
    return;
  }
  heap->size = 0;
}

void insert_heap(struct min_heap *heap, struct tx_queue_node *node) {
  struct heap_node *harr = heap->harr;
  struct heap_node hn;
  struct heap_node temp;
  int ind = 0;
  if (heap->size == heap->capacity) {
    printk("Reached max heap capacity\n");
    return;
  }
  hn.queue_node = node;
  ind = heap->size;
  harr[ind] = hn;
  heap->size++;

  while ((ind != 0) &&
         harr[parent(ind)].queue_node->ftime > harr[ind].queue_node->ftime) {
    temp = harr[ind];
    harr[ind] = harr[parent(ind)];
    harr[parent(ind)] = temp;
    ind = parent(ind);
  }
}

void show_heap(struct min_heap *heap) {
  int ind = 0;
  struct tx_queue_node *node;
  printk("Entered show_heap\n");
  for (; ind < heap->size; ind++) {
    node = heap->harr[ind].queue_node;
    printk("ftime: %ld\n", node->ftime);
  }
}

struct tx_queue_node *top(struct min_heap *heap) {
  if (heap->size == 0) {
    return NULL;
  }
  return heap->harr[0].queue_node;
}

void pop(struct min_heap *heap) {
  struct tx_queue_node *first;
  if (heap->size == 0) {
    return;
  }

  first = heap->harr[0].queue_node;
  heap->harr[0] = heap->harr[heap->size - 1];
  heap->size--;
  heapify(heap, 0);

  kfree(first);
}

void heapify(struct min_heap *heap, int ind) {
  int lc_ind, rc_ind, min_ind;
  struct heap_node temp;
  lc_ind = left(ind);
  rc_ind = right(ind);
  min_ind = ind;
  if ((lc_ind < heap->size) && (heap->harr[lc_ind].queue_node->ftime <
                                heap->harr[ind].queue_node->ftime)) {
    min_ind = lc_ind;
  }
  if ((rc_ind < heap->size) && (heap->harr[rc_ind].queue_node->ftime <
                                heap->harr[min_ind].queue_node->ftime)) {
    min_ind = rc_ind;
  }
  if (min_ind != ind) {
    temp = heap->harr[min_ind];
    heap->harr[min_ind] = heap->harr[ind];
    heap->harr[ind] = temp;
    heapify(heap, min_ind);
  }
}

void free_heap(struct min_heap *heap) {
  kfree(heap->harr);
  heap->harr = NULL;
}
