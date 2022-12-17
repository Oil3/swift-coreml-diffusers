//
//  Pipeline.swift
//  Diffusion
//
//  Created by Pedro Cuenca on December 2022.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import Foundation
import CoreML
import Combine

typealias StableDiffusionProgress = StableDiffusionPipeline.Progress

class Pipeline {
    let pipeline: StableDiffusionPipeline
    
    var progress: StableDiffusionProgress? = nil {
        didSet {
            progressPublisher.value = progress
        }
    }
    lazy private(set) var progressPublisher: CurrentValueSubject<StableDiffusionProgress?, Never> = CurrentValueSubject(progress)


    init(_ pipeline: StableDiffusionPipeline) {
        self.pipeline = pipeline
    }
    
	func generate(prompt: String, negPrompt: String, scheduler: StableDiffusionScheduler, numInferenceSteps stepCount: Int = 50, imageCount: Int = 1, guidance: Float = 7.5, safetyOn: Bool = false, seed: Int? = nil) throws -> [CGImage] {
        let beginDate = Date()
        NSLog("Generating...")
        let theSeed = seed ?? Int.random(in: 0..<Int.max)
        let images = try pipeline.generateImages(
            prompt: prompt,
			negativePrompt: negPrompt,
            imageCount: imageCount,
            stepCount: stepCount,
            seed: theSeed,
			guidanceScale: guidance,
			disableSafety: !safetyOn,
            scheduler: scheduler
        ) { progress in
            handleProgress(progress)
            return true
        }
        NSLog("Got images: \(images) in \(Date().timeIntervalSince(beginDate))")
        // Do we have the righ number of images?
		let imgs = images.compactMap({$0})
		if imgs.count != imageCount {
			throw "Generation failed: got \(imgs.count) instead of \(imageCount)"
		}
        return imgs
    }

    func handleProgress(_ progress: StableDiffusionPipeline.Progress) {
        self.progress = progress
    }
}
