// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Based on https://blog.keras.io/building-autoencoders-in-keras.html

import ArgumentParser

struct Options: ParsableArguments {
    @Option(default: "./dataset", help: ArgumentHelp("Path to the dataset folder", valueName: "dataset-path"))
    var datasetPath: String
    
    @Option(default: 0, help: ArgumentHelp("GPU Index", valueName: "gpu-index"))
    var gpuIndex: UInt
    
    @Option(default: 50, help: ArgumentHelp("Number of epochs", valueName: "epochs"))
    var epochs: Int
    
    @Option(default: "/tmp/tensorboardx", help: ArgumentHelp("TensorBoard logdir path", valueName: "tensorboard-logdir"))
    var tensorboardLogdir: String
    
    @Option(default: 20, help: ArgumentHelp("Number of steps to log a sample image into tensorboard", valueName: "sampleLogPeriod"))
    var sampleLogPeriod: Int
}
