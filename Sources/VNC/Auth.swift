// FoxTerm | Auth.swift
// Copyright (c) 2025-2026 foxterm.app
// Created by foxterm@foxmail.com

import Extension
import Foundation
import libvncclient
import SwiftUI

public extension VNC {
    /// 获取密码
    func getPassword() -> UnsafeMutablePointer<CChar>? {
        guard !password.isEmpty else { return nil }
        return password.bytes
    }

    /// 获取凭据
    func getCredential(_ credentialType: Int32) -> UnsafeMutablePointer<_rfbCredential>? {
        guard credentialType == rfbCredentialTypeUser else {
            return nil
        }

        let credentialPtr = UnsafeMutablePointer<_rfbCredential>.allocate(capacity: 1)
        credentialPtr.initialize(to: _rfbCredential())

        credentialPtr.pointee.userCredential.username = username.bytes
        credentialPtr.pointee.userCredential.password = password.bytes

        return credentialPtr
    }
}
