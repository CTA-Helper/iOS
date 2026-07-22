import SwiftData
import SwiftUI

/**
 A row in an airport's approach list: the procedure's charted name. The runway it serves is
 the header of the section the row sits in.
 */
struct ApproachRow: View {
  let approach: Approach

  var body: some View {
    Text(approach.name)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
  }
}

#if DEBUG
  #Preview {
    List {
      ApproachRow(approach: PreviewData.missoula().approaches[0])
    }
    .modelContainer(.preview)
  }
#endif
