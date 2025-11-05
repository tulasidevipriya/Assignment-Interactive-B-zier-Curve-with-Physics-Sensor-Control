
import UIKit
import CoreMotion
class BezierRopeViewController: UIViewController {
    // MARK: - Bézier Control Points
    var P0: CGPoint = .zero // fixed
    var P3: CGPoint = .zero // fixed
    var P1: CGPoint = .zero // dynamic
    var P2: CGPoint = .zero // dynamic
    var P1v: CGPoint = .zero // velocity
    var P2v: CGPoint = .zero // velocity
    // Spring physics params
    let k: CGFloat = 0.12
    let damping: CGFloat = 0.18
    let dt: CGFloat = 1.0 / 60.0
    // Target positions for P1, P2 (set by gyroscope)
    var P1_target: CGPoint = .zero
    var P2_target: CGPoint = .zero
    // Motion manager
    let motionManager = CMMotionManager()
    // Display link
    var displayLink: CADisplayLink?
    // For drawing
    var bezierLayer = CAShapeLayer()
    var tangentLayer = CAShapeLayer()
    var controlPointLayer = CAShapeLayer()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        // Set up layers
        [bezierLayer, tangentLayer, controlPointLayer].forEach {
            $0.contentsScale = UIScreen.main.scale
            view.layer.addSublayer($0)
        }
        // Set up initial control points
        let W = view.bounds.width
        let H = view.bounds.height
        P0 = CGPoint(x: W * 0.15, y: H * 0.5)
        P3 = CGPoint(x: W * 0.85, y: H * 0.5)
        P1 = CGPoint(x: W * 0.35, y: H * 0.3)
        P2 = CGPoint(x: W * 0.65, y: H * 0.7)
        P1_target = P1
        P2_target = P2
        // Start motion updates
        startMotionUpdates()
        // Start animation
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .default)
    }
    // MARK: - Motion Input
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            // Use pitch and roll to set targets
            let pitch = motion.attitude.pitch // -π/2 ... π/2
            let roll = motion.attitude.roll   // -π ... π
            let W = self.view.bounds.width
            let H = self.view.bounds.height
            // Map pitch/roll to screen coordinates
            let mx = W * (0.5 + CGFloat(roll) / .pi * 0.4)
            let my = H * (0.5 - CGFloat(pitch) / (.pi/2) * 0.3)
            self.P1_target = CGPoint(x: mx - 80, y: my - 60)
            self.P2_target = CGPoint(x: mx + 80, y: my + 60)
        }
    }
    // MARK: - Bézier Math
    func bezier(_ t: CGFloat, _ P0: CGPoint, _ P1: CGPoint, _ P2: CGPoint, _ P3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = uuu * P0.x + 3 * uu * t * P1.x + 3 * u * tt * P2.x + ttt * P3.x
        let y = uuu * P0.y + 3 * uu * t * P1.y + 3 * u * tt * P2.y + ttt * P3.y
        return CGPoint(x: x, y: y)
    }
    func bezierTangent(_ t: CGFloat, _ P0: CGPoint, _ P1: CGPoint, _ P2: CGPoint, _ P3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = 3 * u * u * (P1.x - P0.x) + 6 * u * t * (P2.x - P1.x) + 3 * t * t * (P3.x - P2.x)
        let y = 3 * u * u * (P1.y - P0.y) + 6 * u * t * (P2.y - P1.y) + 3 * t * t * (P3.y - P2.y)
        return CGPoint(x: x, y: y)
    }
    func normalize(_ v: CGPoint) -> CGPoint {
        let len = sqrt(v.x * v.x + v.y * v.y)
        return len > 0 ? CGPoint(x: v.x / len, y: v.y / len) : .zero
    }
    // MARK: - Physics Update
    func springUpdate(_ P: inout CGPoint, _ V: inout CGPoint, _ target: CGPoint) {
        let ax = -k * (P.x - target.x) - damping * V.x
        let ay = -k * (P.y - target.y) - damping * V.y
        V.x += ax * dt
        V.y += ay * dt
        P.x += V.x * dt * 60 // scale for frame rate
        P.y += V.y * dt * 60
    }
    // MARK: - Animation Loop
    @objc func update() {
        springUpdate(&P1, &P1v, P1_target)
        springUpdate(&P2, &P2v, P2_target)
        draw()
    }
    // MARK: - Rendering
    func draw() {
        // Draw Bézier curve
        let path = UIBezierPath()
        let steps = 100
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = bezier(t, P0, P1, P2, P3)
            if i == 0 { path.move(to: p) }
            else { path.addLine(to: p) }
        }
        bezierLayer.path = path.cgPath
        bezierLayer.strokeColor = UIColor.systemTeal.cgColor
        bezierLayer.lineWidth = 4
        bezierLayer.fillColor = nil
        // Draw tangents
        let tangentPath = UIBezierPath()
        for i in stride(from: 10, to: 100, by: 15) {
            let t = CGFloat(i) / 100.0
            let p = bezier(t, P0, P1, P2, P3)
            let tan = normalize(bezierTangent(t, P0, P1, P2, P3))
            let end = CGPoint(x: p.x + tan.x * 40, y: p.y + tan.y * 40)
            tangentPath.move(to: p)
            tangentPath.addLine(to: end)
        }
        tangentLayer.path = tangentPath.cgPath
        tangentLayer.strokeColor = UIColor.systemRed.cgColor
        tangentLayer.lineWidth = 2
        tangentLayer.fillColor = nil
        // Draw control points
        let cpPath = UIBezierPath()
        [P0, P1, P2, P3].forEach { p in
            cpPath.addArc(withCenter: p, radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        }
        controlPointLayer.path = cpPath.cgPath
        controlPointLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.7).cgColor
        controlPointLayer.strokeColor = UIColor.white.cgColor
        controlPointLayer.lineWidth = 2
    }
    // MARK: - Clean up
    deinit {
        displayLink?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }
}
