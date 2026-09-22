import SwiftUI

private enum MoonPlaceMode: String, CaseIterable, Identifiable {
    case v1f = "V1F"
    case v2fx = "V2FX"

    var id: String { rawValue }
}

private struct MoonPlacePatchOption: Identifiable {
    let id: String
    let title: String
    let aliases: [String]
    let excludedAliases: [String]
    let mode: MoonPlaceMode

    func matches(_ item: PatchLibraryItem) -> Bool {
        let name = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
        return aliases.contains { name.localizedCaseInsensitiveContains($0) }
            && !excludedAliases.contains { name.localizedCaseInsensitiveContains($0) }
    }
}

private enum MoonPlaceCatalog {
    static let options: [MoonPlacePatchOption] = [
        .init(id: "v1f-head-sn", title: "CABEZA SN", aliases: ["CABEZA ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-neck-sn", title: "CUELLO SN", aliases: ["CUELLO ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-drag-sn", title: "DRAG SN", aliases: ["DRAG ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-chest-sn", title: "PECHO SN", aliases: ["PECHO ANTENA FFTH"], excludedAliases: [], mode: .v1f),
        .init(id: "v1f-head", title: "CABEZA V1", aliases: ["CABEZA FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-neck", title: "CUELLO V1", aliases: ["CUELLO FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-drag", title: "DRAG V1", aliases: ["DRAG FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v1f-chest", title: "PECHO V1", aliases: ["PECHO FFTH"], excludedAliases: ["ANTENA"], mode: .v1f),
        .init(id: "v2fx-head-sn", title: "CABEZA SN", aliases: ["AIMBOT MOON CABEZA"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-neck-sn", title: "CUELLO SN", aliases: ["AIMBOT MOON VIP CUELLO"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-drag-sn", title: "DRAG SN", aliases: ["AIMBOT MOON DRAG"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-chest-sn", title: "PECHO SN", aliases: ["AIMBOT MOON PECHO"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-head", title: "CABEZA V2", aliases: ["CABEZA ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-neck", title: "CUELLO V2", aliases: ["CUELLO ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-drag", title: "DRAG V2", aliases: ["DRAG ANTENA-FFMAX"], excludedAliases: [], mode: .v2fx),
        .init(id: "v2fx-chest", title: "PECHO V2", aliases: ["PECHO ANTENA FF MAX"], excludedAliases: [], mode: .v2fx)
    ]
}

struct MoonPlaceView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @State private var selectedMode: MoonPlaceMode?
    
    @State private var selectedOption: MoonPlacePatchOption?
    @State private var workingOptionID: String?
    @State private var message: String?
    @State private var showAdvanced = false

    var body: some View {
        ZStack {
            MoonPlaceBackground()
            if selectedMode == nil {
                MoonPlaceModeView(selectedMode: $selectedMode, showAdvanced: $showAdvanced)
                    .transition(.opacity)
            } else {
                MoonPlaceSelectorView(
                    mode: selectedMode!,
                    options: MoonPlaceCatalog.options.filter { $0.mode == selectedMode! },
                    items: patchStore.items,
                    isBusy: patchStore.isBusy,
                    workingOptionID: workingOptionID,
                    onBack: { selectedMode = nil },
                    onToggle: toggle
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: selectedMode)
        .sheet(item: $selectedOption) { option in
            MoonPlacePatchInfoView(option: option, item: matchingItem(for: option))
        }
        .sheet(isPresented: $showAdvanced) {
            PatchProjectsView()
        }
        .alert("RX7 EXTERNAL", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func matchingItem(for option: MoonPlacePatchOption) -> PatchLibraryItem? {
        patchStore.items.first(where: option.matches)
    }

    private func toggle(_ option: MoonPlacePatchOption) {
        guard let item = matchingItem(for: option), let project = item.project else {
            message = "Import the matching .3105 package in Advanced Patches before using this option."
            return
        }
        guard workingOptionID == nil else { return }
        workingOptionID = option.id
        Task.detached(priority: .userInitiated) {
            do {
                if let receipt = DevicePatchService.latestReceipt(projectID: project.id) {
                    try DevicePatchService.restore(receipt: receipt)
                } else {
                    let source = item.summary.schemaVersion >= 2 && item.canInspectContents
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : project
                    _ = try DevicePatchService.apply(project: source)
                }
                await MainActor.run {
                    patchStore.reload()
                    workingOptionID = nil
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    workingOptionID = nil
                    message = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    workingOptionID = nil
                    message = "The patch operation failed. Check device support and the target app."
                }
            }
        }
    }
}

private struct MoonPlaceBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.03, blue: 0.17), Color(red: 0.18, green: 0.02, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? Color.red.opacity(0.32) : Color.blue.opacity(0.28))
                    .frame(width: CGFloat(2 + index % 4), height: CGFloat(2 + index % 4))
                    .offset(x: CGFloat((index * 47) % 330) - 165, y: CGFloat((index * 71) % 690) - 345)
                    .blur(radius: index.isMultiple(of: 3) ? 1 : 0)
                    .animation(.easeInOut(duration: 2.2 + Double(index % 3)).repeatForever(autoreverses: true), value: index)
            }
        }
    }
}

private struct MoonPlaceModeView: View {
    @Binding var selectedMode: MoonPlaceMode?
    @Binding var showAdvanced: Bool
    @State private var hoveredMode: MoonPlaceMode?

    var body: some View {
        VStack(spacing: 28) {
            MoonPlaceHeader(title: "COBALT PROFILES", subtitle: "Select your active control profile")
            
            VStack(spacing: 16) {
                ForEach(MoonPlaceMode.allCases) { mode in
                    Button { 
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        selectedMode = mode 
                    } label: {
                        HStack {
                            ZStack {
                                Circle().fill(MoonPlaceTheme.accentBlue.opacity(0.2)).frame(width: 40, height: 40)
                                Image(systemName: mode == .v1f ? "scope" : "bolt.horizontal.fill")
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                                Text("Premium Control Profile")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("SELECT")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MoonPlaceTheme.accentBlue)
                            }
                        }
                        .padding(20)
                        .background(MoonPlaceTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(MoonPlaceTheme.accentBlue.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            MoonPlaceAccountBadge()
            
            Button {
                showAdvanced = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("ADVANCED SETTINGS")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding()
            }
        }
        .padding(28)
        .frame(maxWidth: 500)
    }
}

private struct MoonPlaceSelectorView: View {
    let mode: MoonPlaceMode
    let options: [MoonPlacePatchOption]
    let items: [PatchLibraryItem]
    let isBusy: Bool
    let workingOptionID: String?
    let onBack: () -> Void
    let onToggle: (MoonPlacePatchOption) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: onBack) { 
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(MoonPlaceTheme.surface, in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        AppLogo(size: 32)
                        Text("COBALT")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(2)
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .foregroundStyle(.white)
                
                VStack(spacing: 6) {
                    Text("CONTROL PANEL")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack {
                        Circle().fill(MoonPlaceTheme.accentBlue).frame(width: 6, height: 6).moonGlow(MoonPlaceTheme.accentBlue, radius: 4)
                        Text("\(mode.rawValue) PROFILE ACTIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                    }
                }
                
                // Status Section
                VStack(spacing: 12) {
                    HStack {
                        Text("SYSTEM STATUS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    HStack {
                        statusPill(title: "SYSTEM", value: "ONLINE", color: MoonPlaceTheme.success)
                        Spacer()
                        statusPill(title: "USER ACCESS", value: "ACTIVE", color: MoonPlaceTheme.success)
                    }
                }
                .padding()
                .background(MoonPlaceTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(MoonPlaceTheme.border, lineWidth: 1))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(options) { option in
                        let item = items.first(where: option.matches)
                        let isApplied = item != nil && DevicePatchService.latestReceipt(projectID: item!.id) != nil
                        
                        Button { 
                            let impact = UIImpactFeedbackGenerator(style: isApplied ? .soft : .medium)
                            impact.impactOccurred()
                            onToggle(option) 
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: workingOptionID == option.id ? "arrow.triangle.2.circlepath" : item == nil ? "cube.box" : "scope")
                                        .font(.title3)
                                        .foregroundStyle(isApplied ? .white : MoonPlaceTheme.accentBlue)
                                    Spacer()
                                    // Custom iOS Switch Visual
                                    ZStack(alignment: isApplied ? .trailing : .leading) {
                                        Capsule()
                                            .fill(isApplied ? MoonPlaceTheme.accentBlue : Color.white.opacity(0.1))
                                            .frame(width: 44, height: 24)
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                            .padding(2)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                    
                                    Text(isApplied ? "ACTIVE" : "DISABLED")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(isApplied ? MoonPlaceTheme.accentBlue : .white.opacity(0.5))
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .background(isApplied ? MoonPlaceTheme.accentBlue.opacity(0.15) : MoonPlaceTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isApplied ? MoonPlaceTheme.accentBlue : MoonPlaceTheme.border, lineWidth: isApplied ? 2 : 1))
                            .moonGlow(MoonPlaceTheme.accentBlue, radius: isApplied ? 6 : 0)
                        }
                        .disabled(isBusy || workingOptionID != nil)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func statusPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
        }
    }
}

private struct MoonPlacePatchInfoView: View {
    let option: MoonPlacePatchOption
    let item: PatchLibraryItem?

    var body: some View {
        VStack(spacing: 18) {
            AppLogo(size: 64)
            Text(option.title).font(.title2.bold())
            Text(item?.packageURL.lastPathComponent ?? "Package not loaded")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Use the tile to apply the packaged patch or restore its original files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}

private struct MoonPlaceHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            AppLogo(size: 70)
            Text(title).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(subtitle).foregroundStyle(.white.opacity(0.65))
        }
    }
}

private struct MoonPlaceAccountBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.shield.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("RX7 EXTERNAL")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("LOCAL ACCESS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
            }
            Spacer()
            Text("NO LOGIN")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(13)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }
}

