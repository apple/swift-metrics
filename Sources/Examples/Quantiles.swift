//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE
//

// copied from https://github.com/evgenyneu/SigmaSwiftStatistics/blob/master/SigmaSwiftStatistics/Quantiles.swift

//
//  Created by Alan James Salmoni on 21/12/2016.
//  Copyright © 2016 Thought Into Design Ltd. All rights reserved.
//

import Foundation

public enum Sigma {
    /**

     The class contains nine functions that calculate sample quantiles corresponding to the given probability. The implementation is the same as in R. This is an implementation of the algorithms described in the Hyndman and Fan paper, 1996:

     https://www.jstor.org/stable/2684934
     https://www.amherst.edu/media/view/129116/original/Sample+Quantiles.pdf

     The documentation of the functions is based on R and Wikipedia:

     https://en.wikipedia.org/wiki/Quantile
     http://stat.ethz.ch/R-manual/R-devel/library/stats/html/quantile.html

     */
    public static let quantiles = SigmaQuantiles()
}

public class SigmaQuantiles {
    /*

     This method calculates quantiles using the inverse of the empirical distribution function.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method1(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let k = Int((probability * count))
        let g = (probability * count) - Double(k)
        var new_probability = 1.0
        if g == 0.0 { new_probability = 0.0 }
        return self.qDef(data, k: k, probability: new_probability)
    }

    /**

     This method uses inverted empirical distribution function with averaging.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method2(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let k = Int(probability * count)
        let g = (probability * count) - Double(k)
        var new_probability = 1.0
        if g == 0.0 { new_probability = 0.5 }
        return self.qDef(data, k: k, probability: new_probability)
    }

    /**

     The 3rd sample quantile method from Hyndman and Fan paper (1996).

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method3(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = -0.5
        let k = Int((probability * count) + m)
        let g = (probability * count) + m - Double(k)
        var new_probability = 1.0
        if g <= 0, k % 2 == 0 { new_probability = 0.0 }
        return self.qDef(data, k: k, probability: new_probability)
    }

    /**

     It uses linear interpolation of the empirical distribution function.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method4(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = 0.0
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     This method uses a piecewise linear function where the knots are the values midway through the steps of the empirical distribution function.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method5(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = 0.5
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     This method is implemented in Microsoft Excel (PERCENTILE.EXC), Minitab and SPSS. It uses linear interpolation of the expectations for the order statistics for the uniform distribution on [0,1].

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method6(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = probability
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     This method is implemented in S, Microsoft Excel (PERCENTILE or PERCENTILE.INC) and Google Docs Sheets (PERCENTILE). It uses linear interpolation of the modes for the order statistics for the uniform distribution on [0, 1].

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method7(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = 1.0 - probability
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     The quantiles returned by the method are approximately median-unbiased regardless of the distribution of x.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method8(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = (probability + 1.0) / 3.0
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     The quantiles returned by this method are approximately unbiased for the expected order statistics if x is normally distributed.

     - parameter data: Array of decimal numbers.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    public func method9(_ data: [Double], probability: Double) -> Double? {
        if probability < 0 || probability > 1 { return nil }
        let data = data.sorted(by: <)
        let count = Double(data.count)
        let m = (0.25 * probability) + (3.0 / 8.0)
        let k = Int((probability * count) + m)
        let probability = (probability * count) + m - Double(k)
        return self.qDef(data, k: k, probability: probability)
    }

    /**

     Shared function for all quantile methods.

     - parameter data: Array of decimal numbers.
     - parameter k: the position of the element in the dataset.
     - parameter probability: the probability value between 0 and 1, inclusive.
     - returns: sample quantile.

     */
    private func qDef(_ data: [Double], k: Int, probability: Double) -> Double? {
        if data.isEmpty { return nil }
        if k < 1 { return data[0] }
        if k >= data.count { return data.last }
        return ((1.0 - probability) * data[k - 1]) + (probability * data[k])
    }
}
