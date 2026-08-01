//  Curve.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//
import Foundation

struct Curve {
    var startValue: Int
    var endValue: Int
    var duration: Int   // in steps (12 steps per beat)
    var type: Int       // -2, -1, 0, 1, 2
    
    // ------------------------------------------------------------------------------------
    // Get the curve value at the specified step. Formulas are from : https://easings.net
    // ------------------------------------------------------------------------------------
    func getValue(at step: Int) -> Int {
        
        var x = 0.0
        if (step < self.duration) {
            x = Double(step) / Double(self.duration)
        }
        else {
            x = 1
        }
        
        if (self.type <= -2) {
            // easeInQuad
            x = pow(x, 3.0)
        }
        else if (self.type == -1) {
            // easeInQuad
            x = pow(x, 2.0)
        }
        else if (self.type == 1) {
            // easeOutQuad
            x = 1.0 - pow(1.0 - x, 2.0)
        }
        else if (self.type >= 2) {
            // easeOutCubic
            x = 1.0 - pow(1.0 - x, 3.0)
        }
        else {
            // linear
        }
        
        if (startValue < endValue) {
            return startValue + Int(x * Double(endValue - startValue))
        }
        else {
            return startValue - Int(x * Double(startValue - endValue))
        }
    }
    
    // ------------------------------------------------------------------------------------
    // Get the curve time of a specific value. Formulas are from : https://easings.net
    // ------------------------------------------------------------------------------------
    func getTimeFor(value: Int) -> Double {
        var t = 0.0
        var x = 0.0
        
        if (startValue < endValue) {
            x =  Double(value - startValue) / Double(endValue - startValue)
        }
        else {
            x =  1 - (Double(value - endValue) / Double(startValue - endValue))
        }
        
        if (self.type <= -2) {
            // easeInQuad
            t = pow(x, 1.0/3.0)
        }
        else if (self.type == -1) {
            // easeInQuad
            t = pow(x, 1.0/2.0)
        }
        else if (self.type == 1) {
            // easeOutQuad
            t = 1.0 - pow(1.0 - x, 1.0/2.0)
        }
        else if (self.type >= 2) {
            // easeOutCubic
            t = 1.0 - pow(1.0 - x, 1.0/3.0)
        }
        else {
            t = x
        }
        
        return t * Double(duration)
    }
}
