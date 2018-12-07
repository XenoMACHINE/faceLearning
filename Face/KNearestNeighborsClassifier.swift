//
//  KNearestNeighborsClassifier.swift
//  Face
//
//  Created by Alexandre Ménielle on 04/12/2018.
//  Copyright © 2018 Ali Hashim. All rights reserved.
//

import Darwin
import Foundation

public class KNearestNeighborsClassifier {
    
    private let data : [[Double]]
    private let labels : [Int]
    private let nNeighbors : Int
    
    public init(data: [[Double]], labels: [Int], nNeighbors: Int = 3) {
        self.data = data
        self.labels = labels
        self.nNeighbors = nNeighbors
        
        guard nNeighbors <= data.count else {
            fatalError("Expected `nNeighbors` (\(nNeighbors)) <= `data.count` (\(data.count))")
        }
        
        guard data.count == labels.count else {
            fatalError("Expected `data.count` (\(data.count)) == `labels.count` (\(labels.count))")
        }
    }
    
    public func predict(_ xTests: [[Double]]) -> [Int] {
        return xTests.map({
            let knn = kNearestNeighbors($0)
            return kNearestNeighborsMajority(knn)
        })
    }
    
    public func test(_ precentage : Int) -> Double{
        var xTrains : [[Double]] = []
        var yTrains : [Int] = []
        var xTests : [[Double]] = []
        var yTests : [Int] = []
        
        for i in 0..<data.count{
            let rand = Int.random(in: 0...100)
            if rand < precentage{
                xTrains.append(data[i])
                yTrains.append(labels[i])
            }else{
                xTests.append(data[i])
                yTests.append(labels[i])
            }
        }
        
        let yPred = self.predict(xTests)
        return accuracy(yTests: yTests, yPred: yPred) * 100
    }
    
    public func accuracy(yTests : [Int], yPred : [Int]) -> Double{
        var count : Double = 0
        for i in 0..<yTests.count{
            if yTests[i] == yPred[i] { count += 1 }
        }
        
        return count / Double(yPred.count)
    }
    
    private func distance(_ xTrain: [Double], _ xTest: [Double]) -> Double {
        let distances = xTrain.enumerated().map { index, _ in
            return pow(xTrain[index] - xTest[index], 2)
        }
        
        return distances.reduce(0, +)
    }
    
    private func kNearestNeighbors(_ xTest: [Double]) -> [(key: Double, value: Int)] {
        var NearestNeighbors = [Double : Int]()
        
        for (index, xTrain) in data.enumerated() {
            NearestNeighbors[distance(xTrain, xTest)] = labels[index]
        }
        
        let kNearestNeighborsSorted = Array(NearestNeighbors.sorted(by: { $0.0 < $1.0 }))[0...nNeighbors-1]
        
        return Array(kNearestNeighborsSorted)
    }
    
    private func kNearestNeighborsMajority(_ knn: [(key: Double, value: Int)]) -> Int {
        var labels = [Int :  Int]()
        
        for neighbor in knn {
            labels[neighbor.value] = (labels[neighbor.value] ?? 0) + 1
        }
        
        for label in labels {
            if label.value == labels.values.max() {
                return label.key
            }
        }
        
        fatalError("Can't find the majority.")
    }
}
