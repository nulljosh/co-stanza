import SwiftUI

// Thin client on the same Supabase project the web app uses. The anon key ships in the web
// bundle already; RLS is what protects writes.
struct Poem: Codable, Identifiable {
    let id: String
    let user_id: String
    let pen_name: String
    let title: String
    let body: String
    let created_at: String
}

@Observable
final class Store {
    static let url = "https://tjsxsqlxjmanwvmywwvw.supabase.co"
    static let anon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRqc3hzcWx4am1hbnd2bXl3d3Z3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0OTc0MDEsImV4cCI6MjA4NjA3MzQwMX0.LphLfho3wdQC20MhtcnBpzQUNuBoTOobrugQbNGxc68"

    var poems: [Poem] = []
    var token: String? = UserDefaults.standard.string(forKey: "token")
    var userId: String? = UserDefaults.standard.string(forKey: "userId")
    var error = ""

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: Self.url + path)!)
        r.httpMethod = method
        r.httpBody = body
        r.setValue(Self.anon, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(token ?? Self.anon)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return r
    }

    func load() async {
        do {
            let (data, _) = try await URLSession.shared.data(for: request("/rest/v1/stanza_poems?select=*&order=created_at.desc&limit=50"))
            poems = try JSONDecoder().decode([Poem].self, from: data)
        } catch { self.error = error.localizedDescription }
    }

    func signIn(email: String, password: String, signUp: Bool) async {
        struct Session: Decodable { let access_token: String?; let user: U?; let msg: String?; let error_description: String?; struct U: Decodable { let id: String } }
        let path = signUp ? "/auth/v1/signup" : "/auth/v1/token?grant_type=password"
        let body = try! JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        do {
            let (data, _) = try await URLSession.shared.data(for: request(path, method: "POST", body: body))
            let s = try JSONDecoder().decode(Session.self, from: data)
            if let t = s.access_token, let u = s.user?.id {
                token = t; userId = u
                UserDefaults.standard.set(t, forKey: "token"); UserDefaults.standard.set(u, forKey: "userId")
                error = ""
            } else { error = s.error_description ?? s.msg ?? (signUp ? "Check your email to confirm." : "Sign in failed") }
        } catch { self.error = error.localizedDescription }
    }

    /// Sends the reset email. The link opens the web app, which sets the new password.
    func forgot(email: String) async {
        let body = try! JSONSerialization.data(withJSONObject: ["email": email])
        var r = request("/auth/v1/recover", method: "POST", body: body)
        r.setValue("https://co-stanza.heyitsmejosh.com/app#/reset", forHTTPHeaderField: "redirect_to")
        _ = try? await URLSession.shared.data(for: r)
        error = "Check your email for a reset link."
    }

    func signOut() {
        token = nil; userId = nil
        UserDefaults.standard.removeObject(forKey: "token"); UserDefaults.standard.removeObject(forKey: "userId")
    }

    func publish(pen: String, title: String, body: String) async -> Bool {
        guard let userId else { return false }
        let json = try! JSONSerialization.data(withJSONObject: ["user_id": userId, "pen_name": pen, "title": title, "body": body])
        do {
            let (data, resp) = try await URLSession.shared.data(for: request("/rest/v1/stanza_poems", method: "POST", body: json))
            if (resp as? HTTPURLResponse)?.statusCode == 401 { signOut(); error = "Session expired. Sign in again."; return false }
            if let p = try? JSONDecoder().decode([Poem].self, from: data).first { poems.insert(p, at: 0); return true }
            error = String(data: data, encoding: .utf8) ?? "Publish failed"
        } catch { self.error = error.localizedDescription }
        return false
    }
}

struct ContentView: View {
    @State private var store = Store()
    @State private var writing = false
    @State private var account = false

    var body: some View {
        NavigationStack {
            List(store.poems) { p in
                NavigationLink(value: p.id) { PoemRow(poem: p) }
            }
            .listStyle(.plain)
            .overlay { if store.poems.isEmpty { ContentUnavailableView("Nothing here yet", systemImage: "text.alignleft", description: Text("Write the first one.")) } }
            .navigationTitle("Co-Stanza")
            .navigationDestination(for: String.self) { id in
                if let p = store.poems.first(where: { $0.id == id }) { PoemView(poem: p) }
            }
            .toolbar {
                ToolbarItem { Button(store.token == nil ? "Sign in" : "Account") { account = true } }
                ToolbarItem { Button("Write", systemImage: "square.and.pencil") { store.token == nil ? (account = true) : (writing = true) } }
            }
            .refreshable { await store.load() }
            .task { await store.load() }
            .sheet(isPresented: $writing) { WriteView(store: store) }
            .sheet(isPresented: $account) { AccountView(store: store) }
        }
    }
}

struct PoemRow: View {
    let poem: Poem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poem.title).font(.headline)
            Text(poem.pen_name).font(.subheadline).foregroundStyle(.secondary)
            Text(poem.body.split(separator: "\n").first.map(String.init) ?? "").lineLimit(1).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}

struct PoemView: View {
    let poem: Poem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(poem.title).font(.largeTitle.bold())
                Text(poem.pen_name).foregroundStyle(.secondary)
                Text(poem.body).font(.body).lineSpacing(6).padding(.top, 16)
            }
            .frame(maxWidth: 560, alignment: .leading).padding(24)
        }
    }
}

struct WriteView: View {
    var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pen") private var pen = ""
    @State private var title = ""
    @State private var text = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Your name", text: $pen)
                TextField("Title", text: $title)
                TextEditor(text: $text).frame(minHeight: 240)
                if !store.error.isEmpty { Text(store.error).foregroundStyle(.red) }
            }
            .navigationTitle("Write")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") { Task { busy = true; if await store.publish(pen: pen, title: title, body: text) { dismiss() }; busy = false } }
                        .disabled(busy || pen.isEmpty || title.isEmpty || text.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 480)
        #endif
    }
}

struct AccountView: View {
    var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                if store.token != nil {
                    Button("Sign out") { store.signOut(); dismiss() }
                } else {
                    TextField("Email", text: $email).textContentType(.emailAddress)
                    SecureField("Password", text: $password)
                    Button("Sign in") { Task { await store.signIn(email: email, password: password, signUp: false); if store.token != nil { dismiss() } } }
                    Button("Create account") { Task { await store.signIn(email: email, password: password, signUp: true) } }
                    Button("Forgot password?") { Task { await store.forgot(email: email) } }.disabled(email.isEmpty)
                    if !store.error.isEmpty { Text(store.error).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(store.token == nil ? "Sign in" : "Account")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 240)
        #endif
    }
}
