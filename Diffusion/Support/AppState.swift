//
//  AppState.swift
//  Diffusion
//
//  Created by Fahim Farook on 17/12/2022.
//

import Foundation
import CoreML
import Combine

class AppState: ObservableObject {
	static let shared = AppState()
	
	@Published var pipeline: Pipeline? = nil
	@Published var modelDir = URL(string: "http://google.com")!
	@Published var models = [String]()

	private let def = UserDefaults.standard
	private(set) lazy var statePublisher: CurrentValueSubject<MainViewState, Never> = CurrentValueSubject(state)

	var state: MainViewState = .loading {
		didSet {
			statePublisher.value = state
		}
	}

	var currentModel: String = "" {
		didSet {
			NSLog("*** Model set")
			Task {
				NSLog("*** Loading model")
				await load(model: currentModel)
				model = currentModel
			}
		}
	}
	
	var prompt: String {
		set {
			def.set(newValue, forKey: "SD_Prompt")
		}
		get {
			return def.value(forKey: "SD_Prompt") as? String ?? "discworld the truth, Highly detailed, Artstation, Colorful"
		}
	}
	
	var negPrompt: String {
		set {
			def.set(newValue, forKey: "SD_NegPrompt")
		}
		get {
			return def.value(forKey: "SD_NegPrompt") as? String ?? "ugly, boring, bad anatomy"
		}
	}
	
	var model: String {
		set {
			def.set(newValue, forKey: "SD_Model")
		}
		get {
			return def.value(forKey: "SD_Model") as? String ?? models.first ?? ""
		}
	}
	
	var scheduler: StableDiffusionScheduler {
		set {
			def.set(newValue.rawValue, forKey: "SD_Scheduler")
		}
		get {
			if let key = def.value(forKey: "SD_Scheduler") as? String {
				return StableDiffusionScheduler(rawValue: key)!
			}
			return  StableDiffusionScheduler.dpmpp
		}
	}

	var guidance: Double {
		set {
			def.set(newValue, forKey: "SD_Guidance")
		}
		get {
			return def.value(forKey: "SD_Guidance") as? Double ?? 7.5
		}
	}
	
	var steps: Double {
		set {
			def.set(newValue, forKey: "SD_Steps")
		}
		get {
			return def.value(forKey: "SD_Steps") as? Double ?? 25
		}
	}
	
	var numImages: Double {
		set {
			def.set(newValue, forKey: "SD_NumImages")
		}
		get {
			return def.value(forKey: "SD_NumImages") as? Double ?? 1
		}
	}

	private init() {
		NSLog("*** AppState initialized")
		// Does the model path exist?
		guard var dir = docDir else {
			state = .error("Could not get user document directory")
			return
		}
		dir.append(path: "Diffusion/models", directoryHint: .isDirectory)
		let fm = FileManager.default
		if !fm.fileExists(atPath: dir.path) {
			NSLog("Models directory does not exist at: \(dir.path). Creating ...")
			try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
		}
		modelDir = dir
		// Find models in model dir
		do {
			let subs = try dir.subDirectories()
			subs.forEach {sub in
				models.append(sub.lastPathComponent)
			}
		} catch {
			state = .error("Could not get sub-folders under model directory: \(dir.path)")
			return
		}
		NSLog("*** Setting model")
		self.currentModel = model
		// On start, didSet does not appear to fire
		Task {
			await load(model: currentModel)
		}
	}
	
	func load(model: String) async {
		NSLog("*** Loading model: \(model)")
		let dir = modelDir.appending(component: model, directoryHint: .isDirectory)
		let fm = FileManager.default
		if !fm.fileExists(atPath: dir.path) {
			let msg = "Model directory: \(model) does not exist at: \(dir.path). Cannot proceed."
			NSLog(msg)
			state = .error(msg)
			return
		}
		let beginDate = Date()
		let configuration = MLModelConfiguration()
		// .all works for v1.4, but not for v1.5
		configuration.computeUnits = .cpuAndGPU
		// TODO: measure performance on different devices
		do {
			let pipeline = try StableDiffusionPipeline(resourcesAt: dir, configuration: configuration, disableSafety: true)
			NSLog("Pipeline loaded in \(Date().timeIntervalSince(beginDate))")
			DispatchQueue.main.async {
				self.pipeline = Pipeline(pipeline)
				self.state = .ready("Ready")
			}
		} catch {
			NSLog("Error loading model: \(error)")
			DispatchQueue.main.async {
				self.state = .error(error.localizedDescription)
			}
		}
	}
}
