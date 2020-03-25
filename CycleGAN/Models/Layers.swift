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

import Foundation
import TensorFlow

public struct Identity: ParameterlessLayer {
    @differentiable
    public func callAsFunction(_ input: Tensorf) -> Tensorf {
        input
    }
}

public struct LeakyRELU: ParameterlessLayer {
    @differentiable
    public func callAsFunction(_ input: Tensorf) -> Tensorf {
        return leakyRelu(input)
    }
}

/// 2-D layer applying instance normalization over a mini-batch of inputs.
///
/// Reference: [Instance Normalization](https://arxiv.org/abs/1607.08022)
public struct InstanceNorm2D<Scalar: TensorFlowFloatingPoint>: Layer {
    /// Learnable parameter scale for affine transformation.
    public var scale: Tensor<Scalar>
    /// Learnable parameter offset for affine transformation.
    public var offset: Tensor<Scalar>
    /// Small value added in denominator for numerical stability.
    @noDerivative public var epsilon: Tensor<Scalar>

    /// Creates a instance normalization 2D Layer.
    ///
    /// - Parameters:
    ///   - featureCount: Size of the channel axis in the expected input.
    ///   - epsilon: Small scalar added for numerical stability.
    public init(featureCount: Int, epsilon: Tensor<Scalar> = Tensor(1e-5)) {
        self.epsilon = epsilon
        scale = Tensor<Scalar>(ones: [featureCount])
        offset = Tensor<Scalar>(zeros: [featureCount])
    }

    /// Returns the output obtained from applying the layer to the given input.
    ///
    /// - Parameter input: The input to the layer. Expected input layout is BxHxWxC.
    /// - Returns: The output.
    @differentiable
    public func callAsFunction(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        // Calculate mean & variance along H,W axes.
        let mean = input.mean(alongAxes: [1, 2])
        let variance = input.variance(alongAxes: [1, 2])
        let norm = (input - mean) * rsqrt(variance + epsilon)
        return norm * scale + offset
    }
}

/// A 2-D layer applying padding with zeros over a mini-batch.
public struct ZeroPad2D<Scalar: TensorFlowFloatingPoint>: ParameterlessLayer {
    /// The padding values along the spatial dimensions.
    @noDerivative public let padding: ((Int, Int), (Int, Int))

    /// Creates a zero-padding 2D Layer.
    ///
    /// - Parameter padding: A tuple of 2 tuples of two integers describing how many elements to
    ///   be padded at the beginning and end of each padding dimensions.
    public init(padding: ((Int, Int), (Int, Int))) {
        self.padding = padding
    }

    /// Creates a zero-padding 2D Layer.
    ///
    /// - Parameter padding: Integer that describes how many elements to be padded
    ///   at the beginning and end of each padding dimensions.
    public init(padding: Int) {
        self.padding = ((padding, padding), (padding, padding))
    }

    /// Returns the output obtained from applying the layer to the given input.
    ///
    /// - Parameter input: The input to the layer. Expected layout is BxHxWxC.
    /// - Returns: The output.
    @differentiable
    public func callAsFunction(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        // Padding applied to height and width dimensions only.
        return input.padded(forSizes: [
            (0, 0),
            padding.0,
            padding.1,
            (0, 0),
        ], mode: .constant(0))
    }
}

public struct ConvLayer: Layer {
    public typealias Input = Tensorf
    public typealias Output = Tensorf

    /// Padding layer.
    public var pad: ZeroPad2D<Float>
    /// Convolution layer.
    public var conv2d: Conv2D<Float>

    /// Creates 2D convolution with padding layer.
    ///
    /// - Parameters:
    ///   - inChannels: Number of input channels in convolution kernel.
    ///   - outChannels: Number of output channels in convolution kernel.
    ///   - kernelSize: Convolution kernel size (both width and height).
    ///   - stride: Stride size (both width and height).
    public init(inChannels: Int, outChannels: Int, kernelSize: Int, stride: Int, padding: Int? = nil) {
        pad = ZeroPad2D<Float>(padding: padding ?? Int(kernelSize / 2))

        conv2d = Conv2D<Float>(filterShape: (kernelSize, kernelSize,
                                             inChannels, outChannels),
                               strides: (stride, stride),
                               filterInitializer: { Tensorf(randomNormal: $0, standardDeviation: Tensorf(0.02)) })
    }

    /// Returns the output obtained from applying the layer to the given input.
    ///
    /// - Parameter input: The input to the layer.
    /// - Returns: The output.
    @differentiable
    public func callAsFunction(_ input: Input) -> Output {
        return input.sequenced(through: pad, conv2d)
    }
}

public struct ResNetBlock<NT: FeatureChannelInitializable>: Layer where NT.TangentVector.VectorSpaceScalar == Float, NT.Input == Tensorf, NT.Output == Tensorf {
    var conv1: Conv2D<Float>
    var norm1: NT
    var conv2: Conv2D<Float>
    var norm2: NT

    var dropOut: Dropout<Float>

    @noDerivative var useDropOut: Bool
    @noDerivative let paddingMode: Tensorf.PaddingMode

    public init(channels: Int,
                paddingMode: Tensorf.PaddingMode,
                normalization _: NT.Type,
                useDropOut: Bool = false,
                filterInit: (TensorShape) -> Tensorf,
                biasInit: (TensorShape) -> Tensorf) {
        conv1 = .init(filterShape: (3, 3, channels, channels),
                      filterInitializer: filterInit,
                      biasInitializer: biasInit)
        norm1 = .init(featureCount: channels)

        conv2 = .init(filterShape: (3, 3, channels, channels),
                      filterInitializer: filterInit,
                      biasInitializer: biasInit)
        norm2 = .init(featureCount: channels)

        dropOut = .init(probability: 0.5)
        self.useDropOut = useDropOut

        self.paddingMode = paddingMode
    }

    @differentiable
    public func callAsFunction(_ input: Tensorf) -> Tensorf {
        var retVal = input.padded(forSizes: [(0, 0), (1, 1), (1, 1), (0, 0)], mode: paddingMode)
        retVal = retVal.sequenced(through: conv1, norm1)
        retVal = relu(retVal)

        if useDropOut {
            retVal = dropOut(retVal)
        }

        retVal = retVal.padded(forSizes: [(0, 0), (1, 1), (1, 1), (0, 0)], mode: paddingMode)
        retVal = retVal.sequenced(through: conv2, norm2)

        return input + retVal
    }
}

extension Array: Module where Element: Layer, Element.Input == Element.Output {
    public typealias Input = Element.Input
    public typealias Output = Element.Output

    @differentiable
    public func callAsFunction(_ input: Input) -> Output {
        differentiableReduce(input) { $1($0) }
    }
}

extension Array: Layer where Element: Layer, Element.Input == Element.Output {}
