// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

#if os(OSX)
    import Cocoa
    public typealias View = NSView
#else
    import UIKit
    public typealias View = UIView
#endif

// MARK: - ImageViewLoadingOptions

/// Options for image loading.
public struct ImageViewLoadingOptions {
    /**
     Custom animations to run when the image is displayed. Default value is nil.
     
     This closure is not called if the response is from memory cache (`isFastResponse`) or if the `animated` property of the reciever is set to `false`. Use `handler` property if you need more control.
     */
    public var animations: ((ImageLoadingView) -> Void)? = nil
    
    /// If true the loaded image is displayed with an animation. Default value is true.
    public var animated = true
    
    /// Custom handler to run when the task completes. Overrides the default completion handler. Default value is nil.
    public var handler: ((ImageLoadingView, ImageTask, ImageResponse, ImageViewLoadingOptions) -> Void)? = nil
    
    /// Default value is nil.
    public var userInfo: Any? = nil

    /// Initializes the receiver.
    public init() {}
}


// MARK: - ImageLoadingView

/// View that supports image loading.
public protocol ImageLoadingView: class {
    /// Cancels the task currently associated with the view.
    func nk_cancelLoading()
    
    /// Loads and displays an image for the given request. Cancels previously started requests.
    func nk_setImageWith(request: ImageRequest, options: ImageViewLoadingOptions) -> ImageTask
    
    /// Gets called when the task that is currently associated with the view completes.
    func nk_imageTask(task: ImageTask, didFinishWithResponse response: ImageResponse, options: ImageViewLoadingOptions)
}

public extension ImageLoadingView where Self: View {
    /// Loads and displays an image for the given URL. Cancels previously started requests.
    public func nk_setImageWith(URL: NSURL) -> ImageTask {
        return nk_setImageWith(ImageRequest(URL: URL))
    }
    
    /// Loads and displays an image for the given request. Cancels previously started requests.
    public func nk_setImageWith(request: ImageRequest) -> ImageTask {
        return nk_setImageWith(request, options: ImageViewLoadingOptions())
    }
}


// MARK: - ImageDisplayingView

/// View that supports displaying images.
public protocol ImageDisplayingView: class {
    /// Displays a given image.
    func nk_displayImage(image: Image?)

}

/// Provides default implementation for image task completion handler.
public extension ImageLoadingView where Self: ImageDisplayingView, Self: View {
    
    /// Default implementation that displays the image and runs animations if necessary.
    public func nk_imageTask(task: ImageTask, didFinishWithResponse response: ImageResponse, options: ImageViewLoadingOptions) {
        if let handler = options.handler {
            handler(self, task, response, options)
            return
        }
        switch response {
        case let .Success(image, info):
            nk_displayImage(image)
            guard options.animated && !info.isFastResponse else {
                return
            }
            if let animations = options.animations {
                animations(self) // User provided custom animations
            } else {
                let animation = CABasicAnimation(keyPath: "opacity")
                animation.duration = 0.25
                animation.fromValue = 0
                animation.toValue = 1
                let layer: CALayer? = self.layer // Make compiler happy
                layer?.addAnimation(animation, forKey: "imageTransition")
            }
        default: return
        }
    }
}


// MARK: - Default ImageLoadingView Implementation

/// Default ImageLoadingView implementation.
public extension ImageLoadingView {

    /// Cancels current image task.
    public func nk_cancelLoading() {
        nk_imageLoadingController.cancelLoading()
    }

    /// Loads and displays an image for the given request. Cancels previously started requests.
    public func nk_setImageWith(request: ImageRequest, options: ImageViewLoadingOptions) -> ImageTask {
        return nk_imageLoadingController.setImageWith(request, options: options)
    }

    /// Returns current task.
    public var nk_imageTask: ImageTask? {
        return nk_imageLoadingController.imageTask
    }
    
    /// Returns image loading controller associated with the view.
    public var nk_imageLoadingController: ImageViewLoadingController {
        if let loader = objc_getAssociatedObject(self, &AssociatedKeys.LoadingController) as? ImageViewLoadingController {
            return loader
        }
        let loader = ImageViewLoadingController { [weak self] in
            self?.nk_imageTask($0, didFinishWithResponse: $1, options: $2)
        }
        objc_setAssociatedObject(self, &AssociatedKeys.LoadingController, loader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return loader
    }
}

private struct AssociatedKeys {
    static var LoadingController = "nk_imageViewLoadingController"
}


// MARK: - ImageLoadingView Conformance

#if os(iOS) || os(tvOS)
    extension UIImageView: ImageDisplayingView, ImageLoadingView {
        /// Displays a given image.
        public func nk_displayImage(image: Image?) {
            self.image = image
        }
    }
#endif

#if os(OSX)
    extension NSImageView: ImageDisplayingView, ImageLoadingView {
        /// Displays a given image.
        public func nk_displayImage(image: Image?) {
            self.image = image
        }
    }
#endif
