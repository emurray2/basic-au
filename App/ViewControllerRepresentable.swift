import SwiftUI
import UIKit

struct AUViewControllerUI: UIViewControllerRepresentable {
	var auViewController: UIViewController?

	init(viewController: UIViewController?) {
		self.auViewController = viewController
	}
	
	func makeUIViewController(context: Context) -> UIViewController {
		let viewController = UIViewController()
		guard let auViewController = self.auViewController else {
			return viewController
		}
		
		viewController.addChild(auViewController)

		let frame: CGRect = viewController.view.bounds
		auViewController.view.frame = frame
		
		viewController.view.addSubview(auViewController.view)
		return viewController
	}
	
	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No opp
    }
}
