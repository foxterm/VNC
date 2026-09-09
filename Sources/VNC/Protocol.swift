// FoxTerm | Protocol.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Foundation
import SwiftUI

public protocol VNCDelegate {
    func disconnect()
    func buffer(vnc: VNC, image: CGImage?)
    func handleDesktopSizeChange(width: Int, height: Int)
}
