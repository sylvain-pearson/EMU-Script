//
//  Measure.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

// -----------------------------------------------
// A measure is a list of steps (musical notes)
// -----------------------------------------------
class Measure {
    
    var steps: [Step]
    
    init() {
        steps = []
    }
    
    func clone() -> Measure {
        let newMeasure = Measure()
        for step in steps {
            newMeasure.steps.append(step.clone())
        }
        return newMeasure
    }
}


