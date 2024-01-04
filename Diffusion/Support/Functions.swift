//
//  Functions.swift
//  Diffusion
//
//  Created by Fahim Farook on 17/12/2022.
//

import Foundation

var docDir: URL? {
	return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
}
