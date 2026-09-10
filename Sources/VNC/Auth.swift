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
        let credentialPtr = UnsafeMutablePointer<_rfbCredential>.allocate(capacity: 1)
        credentialPtr.initialize(to: _rfbCredential())

        if credentialType == rfbCredentialTypeX509 {
            credentialPtr.pointee.x509Credential.x509CACertFile = caCertPath.bytes
            credentialPtr.pointee.x509Credential.x509CACrlFile = caCrlPath.isEmpty ? nil : caCrlPath.bytes
            credentialPtr.pointee.x509Credential.x509ClientCertFile = clientCertPath.isEmpty ? nil : clientCertPath.bytes
            credentialPtr.pointee.x509Credential.x509ClientKeyFile = clientKeyPath.isEmpty ? nil : clientKeyPath.bytes
            // rfbX509CrlVerifyNone: 不进行 CRL 校验
            // rfbX509CrlVerifyClient: 仅校验服务器端点（叶子）证书
            // rfbX509CrlVerifyAll: 校验服务器证书链中的所有证书
            if caCrlPath.isEmpty {
                credentialPtr.pointee.x509Credential.x509CrlVerifyMode = rfbX509CrlVerifyNone.uint8
            } else {
                credentialPtr.pointee.x509Credential.x509CrlVerifyMode = rfbX509CrlVerifyAll.uint8
            }
            return credentialPtr
        }

        if credentialType == rfbCredentialTypeUser {
            credentialPtr.pointee.userCredential.username = username.bytes
            credentialPtr.pointee.userCredential.password = password.bytes

            return credentialPtr
        }
        credentialPtr.deinitialize(count: 1)
        credentialPtr.deallocate()
        return nil
    }
}
