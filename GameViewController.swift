//
//  GameViewController.swift
//  Macvoxel
//

import Cocoa
import MetalKit

class GameView: MTKView {
    // This tells macOS that this view wants to receive keyboard and mouse events
    override var acceptsFirstResponder: Bool { return true }
}

class GameViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Renderer!
    var pauseMenuContainer: NSView!
    
    override var acceptsFirstResponder: Bool { return true }

    override func loadView() {
        let rect = NSRect(x: 0, y: 0, width: 800, height: 600)
        mtkView = GameView(frame: rect)
        self.view = mtkView
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(mtkView)
        // This tells the window to report mouse movement even when not clicking
        self.view.window?.acceptsMouseMovedEvents = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let defaultDevice = MTLCreateSystemDefaultDevice() else { return }
        mtkView.device = defaultDevice
        mtkView.clearColor = MTLClearColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1)
        mtkView.depthStencilPixelFormat = .depth32Float

        guard let newRenderer = Renderer(metalKitView: mtkView) else { return }
        self.renderer = newRenderer
        self.mtkView.delegate = self.renderer
        
        setupPauseMenu()
        lockMouse()
    }
    
    // MARK: - UI Setup
    var mainPauseStack: NSStackView!
    var optionsPauseStack: NSStackView!
    var sensitivityLabel: NSTextField!
    
    private func setupPauseMenu() {
        pauseMenuContainer = NSView(frame: self.view.bounds)
        pauseMenuContainer.wantsLayer = true
        pauseMenuContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        pauseMenuContainer.autoresizingMask = [.width, .height]
        pauseMenuContainer.isHidden = true
        self.view.addSubview(pauseMenuContainer)
        
        // --- Main Menu Stack ---
        mainPauseStack = NSStackView()
        mainPauseStack.orientation = .vertical
        mainPauseStack.alignment = .centerX
        mainPauseStack.spacing = 20
        mainPauseStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Game Paused")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        
        let resumeButton = NSButton(title: "Resume Game", target: self, action: #selector(resumeClicked))
        let optionsButton = NSButton(title: "Options", target: self, action: #selector(optionsClicked))
        let quitButton = NSButton(title: "Quit to Desktop", target: self, action: #selector(quitClicked))
        
        mainPauseStack.addArrangedSubview(titleLabel)
        mainPauseStack.addArrangedSubview(resumeButton)
        mainPauseStack.addArrangedSubview(optionsButton)
        mainPauseStack.addArrangedSubview(quitButton)
        pauseMenuContainer.addSubview(mainPauseStack)
        
        // --- Options Menu Stack ---
        optionsPauseStack = NSStackView()
        optionsPauseStack.orientation = .vertical
        optionsPauseStack.alignment = .centerX
        optionsPauseStack.spacing = 20
        optionsPauseStack.translatesAutoresizingMaskIntoConstraints = false
        optionsPauseStack.isHidden = true
        
        let optionsTitleLabel = NSTextField(labelWithString: "Options")
        optionsTitleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        optionsTitleLabel.textColor = .white
        
        sensitivityLabel = NSTextField(labelWithString: "Mouse Sensitivity: 0.005")
        sensitivityLabel.textColor = .white
        
        let sensitivitySlider = NSSlider(value: 0.005, minValue: 0.001, maxValue: 0.02, target: self, action: #selector(sensitivityChanged(_:)))
        sensitivitySlider.isContinuous = true
        let backButton = NSButton(title: "Back", target: self, action: #selector(backClicked))
        
        optionsPauseStack.addArrangedSubview(optionsTitleLabel)
        optionsPauseStack.addArrangedSubview(sensitivityLabel)
        optionsPauseStack.addArrangedSubview(sensitivitySlider)
        optionsPauseStack.addArrangedSubview(backButton)
        pauseMenuContainer.addSubview(optionsPauseStack)
        
        NSLayoutConstraint.activate([
            mainPauseStack.centerXAnchor.constraint(equalTo: pauseMenuContainer.centerXAnchor),
            mainPauseStack.centerYAnchor.constraint(equalTo: pauseMenuContainer.centerYAnchor),
            optionsPauseStack.centerXAnchor.constraint(equalTo: pauseMenuContainer.centerXAnchor),
            optionsPauseStack.centerYAnchor.constraint(equalTo: pauseMenuContainer.centerYAnchor)
        ])
    }
    
    // MARK: - UI Actions
    @objc func resumeClicked() { togglePause() }
    @objc func optionsClicked() { mainPauseStack.isHidden = true; optionsPauseStack.isHidden = false }
    @objc func backClicked() { optionsPauseStack.isHidden = true; mainPauseStack.isHidden = false }
    @objc func quitClicked() { NSApplication.shared.terminate(self) }
    @objc func sensitivityChanged(_ sender: NSSlider) {
        renderer.mouseSensitivity = sender.floatValue
        sensitivityLabel.stringValue = String(format: "Mouse Sensitivity: %.4f", sender.floatValue)
    }
    
    // MARK: - Input Handling & Pausing
    var isPaused: Bool = false
    var clickMonitor: Any?
    
    @objc func togglePause() {
        if isPaused {
            lockMouse()
        } else {
            unlockMouse()
        }
    }
    
    private func lockMouse() {
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(boolean_t(exactly: 0)!)
        isPaused = false
        pauseMenuContainer.isHidden = true
        self.view.window?.makeFirstResponder(mtkView)
        
        // Click capturing
        if clickMonitor == nil {
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, !self.isPaused else { return event }
                if event.type == .leftMouseDown {
                    print("Left Click!")
                    self.renderer.interact(breakBlock: true)
                } else if event.type == .rightMouseDown {
                    print("Right Click!")
                    self.renderer.interact(breakBlock: false)
                }
                return nil
            }
        }
    }
    
    private func unlockMouse() {
        CGDisplayShowCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(boolean_t(exactly: 1)!)
        isPaused = true
        mainPauseStack.isHidden = false
        optionsPauseStack.isHidden = true
        pauseMenuContainer.isHidden = false
        renderer.keysPressed.removeAll()
        
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
    
    // MARK: - Keyboard & Mouse Events
    
    // WASD Movement
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC Key
            togglePause()
            return
        }
        if !isPaused {
            renderer.keysPressed.insert(event.keyCode)
        }
    }
    
    override func keyUp(with event: NSEvent) {
        renderer.keysPressed.remove(event.keyCode)
    }
    
    override func mouseMoved(with event: NSEvent) {
        if !isPaused {
            renderer.cameraYaw += Float(event.deltaX) * renderer.mouseSensitivity
            // INVERTED Y-AXIS: Swiping down looks up
            renderer.cameraPitch -= Float(event.deltaY) * renderer.mouseSensitivity
            
            // Prevent camera from flipping upside down
            let limit = Float.pi / 2.0 - 0.01
            if renderer.cameraPitch > limit { renderer.cameraPitch = limit }
            if renderer.cameraPitch < -limit { renderer.cameraPitch = -limit }
        }
    }
}
