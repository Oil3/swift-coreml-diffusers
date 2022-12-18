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
	@StateObject var cfg = AppState.shared
	
	@State private var image: SDImage? = nil
	@State private var state: MainViewState = .loading
    @State private var prompt = ""
	@State private var negPrompt = ""
	@State private var scheduler = StableDiffusionScheduler.dpmpp
	@State private var guidance = 7.5
	@State private var width = 512.0
	@State private var height = 512.0
	@State private var steps = 25.0
	@State private var numImages = 1.0
	@State private var seed = -1
	@State private var safetyOn: Bool = true
	@State private var images = [SDImage]()

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
			getBannerView()
			getTopView()
			Spacer().frame(height: 16)
			
			HSplitView {
				getSidebarView().frame(minWidth: 200, maxWidth: 400)
				
				getPreviewPane()
			}
        }
        .padding()
        .onAppear {
			// Set saved values
			prompt = cfg.prompt
			negPrompt = cfg.negPrompt
			scheduler = cfg.scheduler
			guidance = cfg.guidance
			steps = cfg.steps
			numImages = cfg.numImages
			// AppState state subscriber
			stateSubscriber = cfg.statePublisher.sink { state in
				DispatchQueue.main.async {
					self.state = state
				}
			}
			// Pipeline progress subscriber
            progressSubscriber = cfg.pipeline?.progressPublisher.sink { progress in
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
	
	private func getBannerView() -> AnyView? {
		if case .loading = state {
			return AnyView(ErrorBanner(errorMessage: "Loading ..."))
		} else if case let .error(msg) = state {
			return AnyView(ErrorBanner(errorMessage: msg))
		} else if case let .running(progress) = state {
			return getProgressView(progress: progress)
		}
		return nil
	}
	
	private func getTopView() -> AnyView {
		let vw = HStack {
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
		return AnyView(vw)
	}

	private func getSidebarView() -> AnyView {
		let vw = VStack(alignment: .leading) {
			Group {
				Picker("Model", selection: $cfg.currentModel) {
					ForEach(cfg.models, id: \.self) { s in
						Text(s).tag(s)
					}
				}
				
				Spacer().frame(height: 16)
				
				Picker("Scheduler", selection: $scheduler) {
					ForEach(StableDiffusionScheduler.allCases, id: \.self) { s in
						Text(s.rawValue).tag(s)
					}
				}
				
				Spacer().frame(height: 16)
				
				Text("Guidance Scale: \(String(format: "%.1f", guidance))")
				Slider(value: $guidance, in: 0...15, step: 0.1, label: {},
					minimumValueLabel: {Text("0")},
					maximumValueLabel: {Text("15")})
				
				Spacer().frame(height: 16)
			}
			Group {
				Text("Number of Inference Steps: \(String(format: "%.0f", steps))")
				Slider(value: $steps, in: 1...300, step: 1, label: {},
					minimumValueLabel: {Text("1")},
					maximumValueLabel: {Text("300")})
				
				Spacer().frame(height: 16)
				
				Text("Number of Images: \(String(format: "%.0f", numImages))")
				Slider(value: $numImages, in: 1...8, step: 1, label: {},
					minimumValueLabel: {Text("1")},
					maximumValueLabel: {Text("8")})
				
				Spacer().frame(height: 16)
			}
			Group {
				Text("Safety Check On?")
				Toggle("", isOn: $safetyOn)
				
				Spacer().frame(height: 16)
				
				Text("Seed")
				TextField("", value: $seed, format: .number)
			}
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
			Spacer()
		}
		.padding()
		return AnyView(vw)
	}
	
	private func getPreviewPane() -> AnyView {
		let vw = VStack {
			PreviewView(image: $image)
				.scaledToFit()
			
			Divider()
			
			if images.count > 0 {
				ScrollView {
					HStack {
						ForEach(Array(images.enumerated()), id: \.offset) { i, img in
							Image(img.image!, scale: 5, label: Text(""))
								.onTapGesture {
									selectImage(index: i)
								}
							Divider()
						}
					}
				}
				.frame(height: 103)
			}
		}
		.padding()
		return AnyView(vw)
	}
	
	private func submit() {
		if case .running = state { return }
		guard let pipeline = cfg.pipeline else {
			state = .error("No pipeline available!")
			return
		}
		state = .running(nil)
		// Save current config
		cfg.prompt = prompt
		cfg.negPrompt = negPrompt
		cfg.scheduler = scheduler
		cfg.guidance = guidance
		cfg.steps = steps
		cfg.numImages = numImages
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
				let (imgs, seed) = try pipeline.generate(prompt: prompt, negPrompt: negPrompt, scheduler: scheduler, numInferenceSteps: Int(steps), imageCount: Int(numImages), safetyOn: safetyOn, seed: seed)
				progressSubs?.cancel()
				// Create array of SDImage instances from images
				var simgs = [SDImage]()
				for (ndx, img) in imgs.enumerated() {
					var s = SDImage()
					s.image = img
					s.prompt = prompt
					s.negPrompt = prompt
					s.model = cfg.currentModel
					s.scheduler = scheduler.rawValue
					s.seed = seed
					s.numSteps = Int(steps)
					s.guidance = guidance
					s.imageIndex = ndx
					simgs.append(s)
				}
				DispatchQueue.main.async {
					image = simgs.first
					images.append(contentsOf: simgs)
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
	
	private func selectImage(index: Int) {
		image = images[index]
	}
}

struct MainAppView_Previews: PreviewProvider {
	static var previews: some View {
		MainAppView().previewLayout(.sizeThatFits)
	}
}
