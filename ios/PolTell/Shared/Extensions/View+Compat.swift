import Perception
import SwiftUI

extension View {
    /// `onChange(of:)` with the new value only (the two-value form needs iOS 17).
    func onChangeCompat<V: Equatable>(of value: V, _ action: @escaping (V) -> Void) -> some View {
        onChange(of: value, perform: action)
    }

    /// A scroll view that starts at its end (`defaultScrollAnchor(.bottom)` on iOS 17).
    @ViewBuilder
    func bottomAnchoredCompat<ID: Hashable>(_ proxy: ScrollViewProxy, last: ID?) -> some View {
        if #available(iOS 17, *) {
            defaultScrollAnchor(.bottom)
        } else {
            onAppear { if let last { proxy.scrollTo(last, anchor: .bottom) } }
        }
    }
}
