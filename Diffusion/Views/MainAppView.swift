//
//  TextToImageView.swift
//  Diffusion
//
//  Created by Pedro Cuenca on December 2022.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import SwiftUI
import Combine

enum MainViewState {
    case loading
	case idle
	case ready(String)
	case error(String)
    case running(StableDiffusionProgress?)
}

struct MainAppView: View {
	@StateObject var context = AppState.shared
	
	@State private var image: CGImage? = nil
	@State private var state: MainViewState = .loading
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

	@State private var stateSubscriber: Cancellable?
    @State private var progressSubscriber: Cancellable?
    @State private var progressSubs: Cancellable?
	    
	var isBusy: Bool {
		if case .loading = state {
			return true
		}
		if case .running = state {
			return true
		}
		return false
	}
	
    var body: some View {
		VStack(alignment: .leading) {
			if case .loading = state {
				ErrorBanner(errorMessage: "Loading ...")
			} else if case let .error(msg) = state {
				ErrorBanner(errorMessage: msg)
			} else if case let .running(progress) = state {
				getProgressView(progress: progress)
			}
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
				.disabled(isBusy)
            }
			Spacer().frame(height: 16)
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
					PreviewView(image: $image, prompt: $prompt)
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
			// AppState state subscriber
			stateSubscriber = context.statePublisher.sink { state in
				DispatchQueue.main.async {
					self.state = state
				}
			}
			// Pipeline progress subscriber
            progressSubscriber = context.pipeline?.progressPublisher.sink { progress in
                guard let progress = progress else { return }
                state = .running(progress)
            }
        }
    }
	
	private func getProgressView(progress: StableDiffusionProgress?) -> AnyView {
		if let progress = progress, progress.stepCount > 0 {
			let step = Int(progress.step) + 1
			let fraction = Double(step) / Double(progress.stepCount)
			let label = "Step \(step) of \(progress.stepCount)"
			return AnyView(ProgressView(label, value: fraction, total: 1).padding())
		}
		// The first time it takes a little bit before generation starts
		return AnyView(ProgressView(label: {Text("Loading ...")}).progressViewStyle(.linear).padding())
	}
	
	private func submit() {
		if case .running = state { return }
		guard let pipeline = context.pipeline else {
			state = .error("No pipeline available!")
			return
		}
		state = .running(nil)
		// Pipeline progress subscriber
		progressSubs = pipeline.progressPublisher.sink { progress in
			guard let progress = progress else { return }
			DispatchQueue.main.async {
				state = .running(progress)
			}
		}
		DispatchQueue.global(qos: .background).async {
			do {
				// Generate
				let imgs = try pipeline.generate(prompt: prompt, negPrompt: negPrompt, scheduler: scheduler, numInferenceSteps: Int(steps), safetyOn: safetyOn, seed: seed)
				progressSubs?.cancel()
				DispatchQueue.main.async {
					image = imgs.first
					images.append(contentsOf: imgs)
					state = .ready("Image generation complete")
				}
			} catch {
				let msg = "Error generating images: \(error)"
				NSLog(msg)
				DispatchQueue.main.async {
					state = .error(msg)
				}
			}
		}
	}
}

struct MainAppView_Previews: PreviewProvider {
	static var previews: some View {
		MainAppView().previewLayout(.sizeThatFits)
	}
}
