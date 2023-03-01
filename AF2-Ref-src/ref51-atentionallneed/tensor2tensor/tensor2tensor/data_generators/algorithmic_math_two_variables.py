# coding=utf-8
# Copyright 2021 The Tensor2Tensor Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

r"""Data generators for the Mathematical Language Understanding dataset.

The training and test data were generated by assigning symbolic variables
either positive or negative decimal integers and then describing the algebraic
operation to perform. We restrict our variable assignments to the range
x,y->[-1000,1000) and the operations to the set {+,-,*}. To ensure that the
model embraces symbolic variables, the order in which x and y appears in the
expression is randomly chosen. For instance, an input string contrasting from
the example shown above might be y=129,x=531,x-y. Each input string is
accompanied by its target string, which is the evaluation of the mathematical
expression. For this study, all targets considered are decimal integers
represented at the character level. About 12 million unique samples were thus
generated and randomly split into training and test sets at an approximate
ratio of 9:1, respectively.

Example lines from training file:
y=691,x=-999,y*x:-690309
y=210,x=-995,y+x:-785
x=-995,y=210,x*x:990025

For more information check the following paper:
Artit Wangperawong. Attending to Mathematical Language with Transformers,
arXiv:1812.02825 (https://arxiv.org/abs/1812.02825).
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import tarfile
import requests

from tensor2tensor.data_generators import problem
from tensor2tensor.data_generators import text_problems
from tensor2tensor.utils import registry

import tensorflow.compat.v1 as tf


_URL = ("https://art.wangperawong.com/mathematical_language_understanding"
        "_train.tar.gz")


def _download_mlu_data(tmp_dir, data_dir):
  """Downloads and extracts the dataset.

  Args:
    tmp_dir: temp directory to download and extract the dataset
    data_dir: The base directory where data and vocab files are stored.

  Returns:
    tmp_dir: temp directory containing the raw data.
  """
  if not tf.gfile.Exists(data_dir):
    tf.gfile.MakeDirs(data_dir)

  filename = os.path.basename(_URL)
  file_path = os.path.join(tmp_dir, filename)
  headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) "
                           "AppleWebKit/537.36 (KHTML, like Gecko) "
                           "Chrome/63.0.3239.132 Safari/537.36"}
  resp = requests.get(_URL, headers=headers)
  with open(file_path, "wb") as f:
    f.write(resp.content)

  with tarfile.open(file_path, "r:gz") as tar:
    def is_within_directory(directory, target):
        
        abs_directory = os.path.abspath(directory)
        abs_target = os.path.abspath(target)
    
        prefix = os.path.commonprefix([abs_directory, abs_target])
        
        return prefix == abs_directory
    
    def safe_extract(tar, path=".", members=None, *, numeric_owner=False):
    
        for member in tar.getmembers():
            member_path = os.path.join(path, member.name)
            if not is_within_directory(path, member_path):
                raise Exception("Attempted Path Traversal in Tar File")
    
        tar.extractall(path, members, numeric_owner=numeric_owner) 
        
    
    safe_extract(tar, tmp_dir)

  return tmp_dir


@registry.register_problem
class AlgorithmicMathTwoVariables(text_problems.Text2TextProblem):
  """Mathematical language understanding, see arxiv.org/abs/1812.02825."""

  @property
  def vocab_type(self):
    return text_problems.VocabType.CHARACTER

  @property
  def dataset_splits(self):
    return [{
        "split": problem.DatasetSplit.TRAIN,
        "shards": 10,
    }, {
        "split": problem.DatasetSplit.EVAL,
        "shards": 1,
    }]

  @property
  def is_generate_per_split(self):
    return False

  def generate_samples(self, data_dir, tmp_dir, dataset_split):
    """Downloads and extracts the dataset and generates examples.

    Args:
      data_dir: The base directory where data and vocab files are stored.
      tmp_dir: temp directory to download and extract the dataset.
      dataset_split: split of the data-set.

    Yields:
      The data examples.
    """
    if not tf.gfile.Exists(tmp_dir):
      tf.gfile.MakeDirs(tmp_dir)

    if not tf.gfile.Exists(data_dir):
      tf.gfile.MakeDirs(data_dir)

    # Download and extract.
    download_path = _download_mlu_data(tmp_dir, data_dir)
    filepath = os.path.join(download_path, "symbolic_math_train.txt")
    with open(filepath, "r") as fp:
      for l in fp:
        prob, ans = l.strip().split(":")
        yield {"inputs": prob, "targets": ans}
