//
//  TextToImageView.swift
//  Diffusion
//
//  Created by Pedro Cuenca on December 2022.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import SwiftUI
import Combine

enum GenerationState {
    case startup
    case running(StableDiffusionProgress?)
    case idle(String)
}

struct TextToImageView: View {
    @EnvironmentObject var context: DiffusionGlobals
	
	@State private var image: CGImage? = nil
	@State private var state: GenerationState = .startup
    @State private var prompt = "discworld the fifth elephant, Highly detailed, Artstation, Colorful"
	@State private var negPrompt = "ugly, boring, bad anatomy"
	@State private var scheduler = StableDiffusionScheduler.dpmpp
	@State private var guidance = 7.5
	@State private var width = 512.0
	@State private var height = 512.0
	@State private var steps = 25.0
	@State private var numImages = 1.0
	@State private var seed: Int? = nil
	@State private var safetyOn: Bool = true
	@State private var images = [CGImage]()

    @State private var progressSubscriber: Cancellable?
	

	func submit() {
        if case .running = state { return }
        Task {
            state = .running(nil)
            await generate(pipeline: context.pipeline, prompt: prompt)
            state = .idle(prompt)
        }
    }
    
    var body: some View {
		VStack(alignment: .leading) {
            HStack {
				VStack {
					TextField("Prompt", text: $prompt)
						.textFieldStyle(.roundedBorder)
					TextField("Negative Prompt", text: $negPrompt)
						.textFieldStyle(.roundedBorder)
				}
                Button("Generate") {
                    submit()
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
			Spacer()
			HStack(alignment: .top) {
				VStack(alignment: .leading) {
					Group {
						Picker("Scheduler", selection: $scheduler) {
							ForEach(StableDiffusionScheduler.allCases, id: \.self) { s in
								Text(s.rawValue).tag(s)
							}
						}
						Text("")
						Text("Guidance Scale: \(String(format: "%.1f", guidance))")
						Slider(value: $guidance, in: 0...15, step: 0.1, label: {},
							minimumValueLabel: {Text("0")},
							maximumValueLabel: {Text("15")})
						Text("")
					}
					Group {
						Text("Number of Inference Steps: \(String(format: "%.0f", steps))")
						Slider(value: $steps, in: 1...300, step: 1, label: {},
							minimumValueLabel: {Text("1")},
							maximumValueLabel: {Text("300")})
						Text("")
						Text("Number of Images: \(String(format: "%.0f", numImages))")
						Slider(value: $numImages, in: 1...8, step: 1, label: {},
							minimumValueLabel: {Text("1")},
							maximumValueLabel: {Text("8")})
						Text("")
					}
					Text("Safety Check On?")
					Toggle("", isOn: $safetyOn)
					Text("")
					Text("Seed")
					TextField("", value: $seed, format: .number)
//					Group {
//						Text("Image Width")
//						Slider(value: $width, in: 64...2048, step: 8, label: {},
//							   minimumValueLabel: {Text("64")},
//							   maximumValueLabel: {Text("2048")})
//						Text("Image Height")
//						Slider(value: $height, in: 64...2048, step: 8, label: {},
//							   minimumValueLabel: {Text("64")},
//							   maximumValueLabel: {Text("2048")})
//					}
				}
				Spacer()
				VStack {
					PreviewView(image: $image, state: $state)
						.scaledToFit()
					
					Divider()
					if images.count > 0 {
						ScrollView {
							HStack {
								ForEach(images, id: \.self) { i in
									Image(i, scale: 5, label: Text(""))
									Divider()
								}
							}
						}
						.frame(height: 103)
					}
				}
			}
            Spacer()
        }
        .padding()
        .onAppear {
            progressSubscriber = context.pipeline?.progressPublisher.sink { progress in
                guard let progress = progress else { return }
                state = .running(progress)
            }
        }
    }
	
	func generate(pipeline: Pipeline?, prompt: String) async {
		guard let pipeline = pipeline else { return }
		do {
			let imgs = try pipeline.generate(prompt: prompt, negPrompt: negPrompt, scheduler: scheduler, numInferenceSteps: Int(steps), safetyOn: safetyOn, seed: seed)
			image = imgs.first
			images.append(contentsOf: imgs)
		} catch {
			NSLog("Error generating images: \(error)")
		}
	}
}

struct TextToImageView_Previews: PreviewProvider {
	static var previews: some View {
		TextToImageView().previewLayout(.sizeThatFits).environmentObject(DiffusionGlobals())
	}
}
