//
//  JsonEditorController.swift
//  FlowDown
//
//  Created by Willow Zhang on 10/31/25.
//

import AlertController
import RunestoneEditor
import Storage
import UIKit

class JsonEditorController: CodeEditorController {
    var onTextDidChange: ((String) -> Void)?

    var secondaryMenuBuilder: ((JsonEditorController) -> (UIMenu))? {
        didSet {
            if let secondaryMenuBuilder {
                navigationItem.rightBarButtonItems = [
                    .init(systemItem: .edit, menu: secondaryMenuBuilder(self)),
                    doneBarButtonItem,
                ]
            } else {
                navigationItem.rightBarButtonItems = [doneBarButtonItem]
            }
        }
    }

    init(text: String) {
        super.init(language: "json", text: text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.editorDelegate = self
    }

    override func done() {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textView.text = "{}"
            onTextDidChange?(textView.text)
            super.done()
            return
        }
        guard let data = textView.text.data(using: .utf8) else {
            presentErrorAlert(message: "Unable to decode text into data.")
            return
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard object is [String: Any] else {
                throw NSError(
                    domain: "JSONValidation",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "JSON must be an object (dictionary), not an array or primitive.")]
                )
            }
            Logger.ui.infoFile("JsonEditorController done with valid JSON object")
        } catch {
            presentErrorAlert(message: "Unable to parse JSON: \(error.localizedDescription)")
            return
        }
        super.done()
    }

    private func presentErrorAlert(message: String) {
        let alert = AlertViewController(
            title: "Error",
            message: message
        ) { context in
            context.addAction(title: "OK", attribute: .accent) {
                context.dispose()
            }
        }
        present(alert, animated: true)
    }
}

extension JsonEditorController: TextViewDelegate {
    func textViewDidChange(_ textView: TextView) {
        onTextDidChange?(textView.text)
    }
}
