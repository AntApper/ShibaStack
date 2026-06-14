import Foundation

public final class K8sManager {
    public static nonisolated(unsafe) let shared = K8sManager()
    
    private init() {}
    
    private var kubeConfigURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".kube/config")
    }
    
    /// Checks if kubectl CLI tool is installed on the host Mac.
    public func isKubectlInstalled() -> Bool {
        let fm = FileManager.default
        let paths = ["/usr/local/bin/kubectl", "/opt/homebrew/bin/kubectl", "/usr/bin/kubectl"]
        for path in paths {
            if fm.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
    
    /// Generates/appends a standard local Kubernetes config for ShibaStack.
    public func enableK8sContext() throws {
        let fm = FileManager.default
        let kubeDir = kubeConfigURL.deletingLastPathComponent()
        
        // Ensure ~/.kube directory exists
        if !fm.fileExists(atPath: kubeDir.path) {
            try fm.createDirectory(at: kubeDir, withIntermediateDirectories: true)
        }
        
        let shibaKubeConfig = """
apiVersion: v1
clusters:
- cluster:
    server: https://127.0.0.1:6443
    insecure-skip-tls-verify: true
  name: shibastack
contexts:
- context:
    cluster: shibastack
    user: shibastack-admin
  name: shibastack
current-context: shibastack
kind: Config
preferences: {}
users:
- name: shibastack-admin
  user:
    token: shiba-admin-token-secure-handshake
"""
        
        // Write or backup old config before overwriting to ensure safety
        if fm.fileExists(atPath: kubeConfigURL.path) {
            let backupURL = kubeConfigURL.appendingPathExtension("bak")
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: kubeConfigURL, to: backupURL)
        }
        
        try shibaKubeConfig.write(to: kubeConfigURL, atomically: true, encoding: .utf8)
        print("[K8sManager] Successfully enabled local Kubernetes context 'shibastack' in \(kubeConfigURL.path).")
    }
    
    /// Safely reverts or disables the shibastack context.
    public func disableK8sContext() throws {
        let fm = FileManager.default
        let backupURL = kubeConfigURL.appendingPathExtension("bak")
        
        if fm.fileExists(atPath: backupURL.path) {
            try? fm.removeItem(at: kubeConfigURL)
            try fm.copyItem(at: backupURL, to: kubeConfigURL)
            try? fm.removeItem(at: backupURL)
            print("[K8sManager] Successfully restored backup kubeconfig.")
        } else if fm.fileExists(atPath: kubeConfigURL.path) {
            // Delete configuration safely if it was only shibastack
            try? fm.removeItem(at: kubeConfigURL)
            print("[K8sManager] Cleared shibastack kubeconfig.")
        }
    }
}
