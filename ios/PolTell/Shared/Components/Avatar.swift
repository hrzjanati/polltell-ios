import Perception
import SwiftUI
import PolTellCore

struct Avatar: View {
    let name: String
    var photo: String? = nil
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let photo, let data = Data(base64Encoded: photo), let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.65, green: 0.67, blue: 0.72), Color(red: 0.52, green: 0.54, blue: 0.58)],
                                   startPoint: .top, endPoint: .bottom)
                    if let text = AvatarImage.initials(name) {
                        Text(text).font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill").font(.system(size: size * 0.5)).foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
