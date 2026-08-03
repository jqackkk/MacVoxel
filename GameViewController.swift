//
//  GameViewController.swift
//  Macvoxel
//

import Cocoa
import MetalKit

class GameView: MTKView {
    override var acceptsFirstResponder: Bool { return true }
}

class GameViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Renderer!
    var pauseMenuContainer: NSView!
    
    // Hotbar Variables
    var hotbarStack: NSStackView!
    var hotbarSlotViews: [NSView] = []
    let hotbarBlocks: [BlockType] = [.grass, .dirt, .cobblestone, .air, .air, .air, .air, .air, .air]
    var selectedHotbarSlot = 0
    
    override var acceptsFirstResponder: Bool { return true }

    override func loadView() {
        let rect = NSRect(x: 0, y: 0, width: 800, height: 600)
        mtkView = GameView(frame: rect)
        self.view = mtkView
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(mtkView)
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
        
        setupHotbar()
        setupPauseMenu()
        lockMouse()
    }
    
    // MARK: - UI Setup
    private func getTextureSlice(for block: BlockType) -> CGImage? {
        // FIXED: Do not draw any icons for empty air slots
        if block == .air { return nil } 
        
        guard let atlasImage = NSImage(named: "TextureAtlas"),
              let cgImage = atlasImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Image is 6 columns wide, 4 rows tall
        let colWidth = cgImage.width / 6
        let rowHeight = cgImage.height / 4
        
        // FIXED: Subtract 1 so Grass (ID 1) perfectly maps to Row 0!
        let blockIndex = Int(block.rawValue) - 1
        
        // We want the Front face for the UI (Column Index 2)
        let cropRect = CGRect(x: colWidth * 2, y: rowHeight * blockIndex, width: colWidth, height: rowHeight)
        return cgImage.cropping(to: cropRect)
    }
    
    private func setupHotbar() {
        hotbarStack = NSStackView()
        hotbarStack.orientation = .horizontal
        hotbarStack.spacing = 5
        hotbarStack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(hotbarStack)
        
        NSLayoutConstraint.activate([
            hotbarStack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            hotbarStack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -20)
        ])
        
        for i in 0..<9 {
            let slotView = NSView()
            slotView.translatesAutoresizingMaskIntoConstraints = false
            slotView.wantsLayer = true
            slotView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
            slotView.layer?.borderWidth = 2
            slotView.layer?.cornerRadius = 4
            
            NSLayoutConstraint.activate([
                slotView.widthAnchor.constraint(equalToConstant: 44),
                slotView.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            let block = hotbarBlocks[i]
            if let blockImage = getTextureSlice(for: block) {
                let imageLayer = CALayer()
                imageLayer.contents = blockImage
                imageLayer.magnificationFilter = .nearest
                imageLayer.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
                slotView.layer?.addSublayer(imageLayer)
            }
            
            let label = NSTextField(labelWithString: "\(i+1)")
            label.font = NSFont.boldSystemFont(ofSize: 12)
            label.textColor = .white
            label.isBordered = false
            label.isEditable = false
            label.drawsBackground = false
            label.translatesAutoresizingMaskIntoConstraints = false
            
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black
            shadow.shadowOffset = NSSize(width: 1, height: -1)
            shadow.shadowBlurRadius = 2
            label.shadow = shadow
            
            slotView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: slotView.leadingAnchor, constant: 4),
                label.topAnchor.constraint(equalTo: slotView.topAnchor, constant: 4)
            ])
            
            hotbarSlotViews.append(slotView)
            hotbarStack.addArrangedSubview(slotView)
        }
        updateHotbarSelection()
    }
    
    private func updateHotbarSelection() {
        for (index, view) in hotbarSlotViews.enumerated() {
            if index == selectedHotbarSlot {
                view.layer?.borderColor = NSColor.white.cgColor
                view.layer?.borderWidth = 4
                renderer.activeBlockType = hotbarBlocks[index].rawValue
            } else {
                view.layer?.borderColor = NSColor.darkGray.cgColor
                view.layer?.borderWidth = 2
            }
        }
    }
    
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
        
        mainPauseStack = NSStackView()
        mainPauseStack.orientation = .vertical
        mainPauseStack.alignment = .centerX
        mainPauseStack.spacing = 20
        mainPauseStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Game Paused")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false
        
        let resumeButton = NSButton(title: "Resume Game", target: self, action: #selector(resumeClicked))
        let optionsButton = NSButton(title: "Options", target: self, action: #selector(optionsClicked))
        let quitButton = NSButton(title: "Quit to Desktop", target: self, action: #selector(quitClicked))
        
        mainPauseStack.addArrangedSubview(titleLabel)
        mainPauseStack.addArrangedSubview(resumeButton)
        mainPauseStack.addArrangedSubview(optionsButton)
        mainPauseStack.addArrangedSubview(quitButton)
        pauseMenuContainer.addSubview(mainPauseStack)
        
        optionsPauseStack = NSStackView()
        optionsPauseStack.orientation = .vertical
        optionsPauseStack.alignment = .centerX
        optionsPauseStack.spacing = 20
        optionsPauseStack.translatesAutoresizingMaskIntoConstraints = false
        optionsPauseStack.isHidden = true
        
        let optionsTitleLabel = NSTextField(labelWithString: "Options")
        optionsTitleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        optionsTitleLabel.textColor = .white
        optionsTitleLabel.isBordered = false
        optionsTitleLabel.isEditable = false
        optionsTitleLabel.drawsBackground = false
        
        sensitivityLabel = NSTextField(labelWithString: "Mouse Sensitivity: 0.005")
        sensitivityLabel.textColor = .white
        sensitivityLabel.isBordered = false
        sensitivityLabel.isEditable = false
        sensitivityLabel.drawsBackground = false
        
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
    
    @objc func resumeClicked() { togglePause() }
    @objc func optionsClicked() { mainPauseStack.isHidden = true; optionsPauseStack.isHidden = false }
    @objc func backClicked() { optionsPauseStack.isHidden = true; mainPauseStack.isHidden = false }
    @objc func quitClicked() { NSApplication.shared.terminate(self) }
    @objc func sensitivityChanged(_ sender: NSSlider) {
        renderer.mouseSensitivity = sender.floatValue
        sensitivityLabel.stringValue = String(format: "Mouse Sensitivity: %.4f", sender.floatValue)
    }
    
    var isPaused: Bool = false
    var clickMonitor: Any?
    
    @objc func togglePause() {
        if isPaused { lockMouse() } else { unlockMouse() }
    }
    
    private func lockMouse() {
        CGDisplayHideCursor(CGMainDisplayID())
        CGAssociateMouseAndMouseCursorPosition(boolean_t(exactly: 0)!)
        isPaused = false
        pauseMenuContainer.isHidden = true
        self.view.window?.makeFirstResponder(mtkView)
        
        if clickMonitor == nil {
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown]) { [weak self] event in
                guard let self = self, !self.isPaused else { return event }
                
                if event.type == .leftMouseDown {
                    self.renderer.isBreaking = true
                } else if event.type == .leftMouseUp {
                    self.renderer.isBreaking = false
                    self.renderer.breakProgress = 0.0
                    self.renderer.breakingBlockPosition = nil
                } else if event.type == .rightMouseDown {
                    self.renderer.interact()
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
        
        renderer.isBreaking = false
        renderer.breakProgress = 0.0
        renderer.breakingBlockPosition = nil
        
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
    
    // MARK: - Keyboard & Mouse Events
    override func performKeyEquivalent(with event: NSEvent) -> Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { togglePause(); return }
        
        if let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1 && num <= 9 {
            selectedHotbarSlot = num - 1
            updateHotbarSelection()
            return
        }
        if !isPaused { renderer.keysPressed.insert(event.keyCode) }
    }
    
    override func keyUp(with event: NSEvent) { renderer.keysPressed.remove(event.keyCode) }
    
    override func mouseMoved(with event: NSEvent) {
        if !isPaused {
            renderer.cameraYaw += Float(event.deltaX) * renderer.mouseSensitivity
            renderer.cameraPitch -= Float(event.deltaY) * renderer.mouseSensitivity
            
            let limit = Float.pi / 2.0 - 0.01
            if renderer.cameraPitch > limit { renderer.cameraPitch = limit }
            if renderer.cameraPitch < -limit { renderer.cameraPitch = -limit }
        }
    }
    
    override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    override func rightMouseDragged(with event: NSEvent) { mouseMoved(with: event) }
}
