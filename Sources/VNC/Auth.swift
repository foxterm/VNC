// FoxTerm | Auth.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libvncclient
import SwiftUI

public extension VNC {
    func getPassword() -> UnsafeMutablePointer<CChar> {
        password.bytes
    }

    func getCredential(_ credentialType: Int32) -> UnsafeMutablePointer<_rfbCredential>? {
        guard credentialType == rfbCredentialTypeUser else {
            return nil
        }
        let cPointer = UnsafeMutablePointer<_rfbCredential>.allocate(capacity: 1)
        cPointer.pointee = rfbCredential()
        cPointer.pointee.userCredential.username = username.bytes
        cPointer.pointee.userCredential.password = password.bytes
        return cPointer
    }
}
