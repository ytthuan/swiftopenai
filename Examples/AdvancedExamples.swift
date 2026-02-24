// AdvancedExamples.swift
// Standalone reference file — NOT compiled by the package.
// Each function demonstrates an advanced SwiftOpenAI workflow.

import Foundation
import SwiftOpenAI

// MARK: - Audio Transcription

/// Transcribes an audio file using the Whisper model.
///
/// Loads audio data from a file path, sends it to the transcription API,
/// and prints the resulting text.
///
/// Usage:
/// ```swift
/// try await transcribeAudio(at: "/path/to/recording.mp3")
/// ```
func transcribeAudio(at filePath: String) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    let audioURL = URL(fileURLWithPath: filePath)
    let audioData = try Data(contentsOf: audioURL)
    let filename = audioURL.lastPathComponent

    let transcription = try await client.audio.transcriptions.create(
        file: audioData,
        filename: filename,
        model: "whisper-1",
        language: "en",
        responseFormat: "verbose_json",
        temperature: 0.0
    )

    print("Transcription: \(transcription.text)")
}

// MARK: - Text-to-Speech

/// Generates speech audio from text and saves it to a file.
///
/// Uses the "tts-1-hd" model with the "nova" voice and writes the
/// resulting audio data to the specified output path.
///
/// Usage:
/// ```swift
/// try await textToSpeech(
///     text: "Hello, world!",
///     outputPath: "/tmp/speech.mp3"
/// )
/// ```
func textToSpeech(text: String, outputPath: String) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    let audioData = try await client.audio.speech.create(
        model: "tts-1-hd",
        input: text,
        voice: "nova",
        responseFormat: "mp3",
        speed: 1.0
    )

    let outputURL = URL(fileURLWithPath: outputPath)
    try audioData.write(to: outputURL)
    print("Saved \(audioData.count) bytes of audio to \(outputPath)")
}

// MARK: - File Upload + Fine-Tuning Workflow

/// Uploads a JSONL training file and creates a fine-tuning job,
/// then polls until the job completes or fails.
///
/// The training file should contain JSONL lines in the chat format:
/// ```
/// {"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
/// ```
///
/// Usage:
/// ```swift
/// try await fineTuneWorkflow(
///     trainingFilePath: "/path/to/training.jsonl",
///     model: "gpt-4o-mini-2024-07-18",
///     suffix: "my-custom-model"
/// )
/// ```
func fineTuneWorkflow(
    trainingFilePath: String,
    model: String = "gpt-4o-mini-2024-07-18",
    suffix: String? = nil
) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    // Step 1: Upload the training file
    let fileURL = URL(fileURLWithPath: trainingFilePath)
    let fileData = try Data(contentsOf: fileURL)

    let uploadedFile = try await client.files.create(
        file: fileData,
        filename: fileURL.lastPathComponent,
        purpose: "fine-tune"
    )
    print("Uploaded file: \(uploadedFile.id)")

    // Step 2: Create the fine-tuning job
    let job = try await client.fineTuning.jobs.create(
        model: model,
        trainingFile: uploadedFile.id,
        suffix: suffix,
        seed: 42
    )
    print("Created fine-tuning job: \(job.id) — status: \(job.status)")

    // Step 3: Poll for completion
    var currentJob = job
    while currentJob.status == "validating_files"
        || currentJob.status == "queued"
        || currentJob.status == "running"
    {
        try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
        currentJob = try await client.fineTuning.jobs.retrieve(job.id)
        print("Job \(job.id) status: \(currentJob.status)")
    }

    // Step 4: Print results
    if currentJob.status == "succeeded" {
        print("Fine-tuning complete! Model: \(currentJob.fineTunedModel ?? "unknown")")
    } else {
        print("Fine-tuning ended with status: \(currentJob.status)")
    }

    // Optionally list recent events
    let events = try await client.fineTuning.jobs.listEvents(job.id, limit: 5)
    for event in events.data {
        print("  Event: \(event.message)")
    }
}

// MARK: - Batch Processing Workflow

/// Uploads a JSONL batch request file, creates a batch, and checks its status.
///
/// The batch file should contain one JSON request per line:
/// ```
/// {"custom_id": "req-1", "method": "POST", "url": "/v1/chat/completions", "body": {"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}}
/// ```
///
/// Usage:
/// ```swift
/// try await batchWorkflow(inputFilePath: "/path/to/batch_requests.jsonl")
/// ```
func batchWorkflow(inputFilePath: String) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    // Step 1: Upload the batch input file
    let fileURL = URL(fileURLWithPath: inputFilePath)
    let fileData = try Data(contentsOf: fileURL)

    let uploadedFile = try await client.files.create(
        file: fileData,
        filename: fileURL.lastPathComponent,
        purpose: "batch"
    )
    print("Uploaded batch input file: \(uploadedFile.id)")

    // Step 2: Create the batch
    let batch = try await client.batches.create(
        inputFileId: uploadedFile.id,
        endpoint: "/v1/chat/completions",
        completionWindow: "24h",
        metadata: ["project": "example", "run": "1"]
    )
    print("Created batch: \(batch.id) — status: \(batch.status)")

    // Step 3: Poll for completion
    var currentBatch = batch
    while currentBatch.status == "validating"
        || currentBatch.status == "in_progress"
        || currentBatch.status == "finalizing"
    {
        try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
        currentBatch = try await client.batches.retrieve(batch.id)
        print("Batch \(batch.id) status: \(currentBatch.status)")
    }

    // Step 4: Retrieve results
    if currentBatch.status == "completed", let outputFileId = currentBatch.outputFileId {
        let resultData = try await client.files.content(outputFileId)
        let resultString = String(data: resultData, encoding: .utf8) ?? ""
        print("Batch results (\(resultData.count) bytes):\n\(resultString.prefix(500))")
    } else {
        print("Batch ended with status: \(currentBatch.status)")
    }
}

// MARK: - Vector Store Workflow

/// Creates a vector store, uploads files into it, and performs a search.
///
/// Usage:
/// ```swift
/// try await vectorStoreWorkflow(
///     filePaths: ["/path/to/doc1.pdf", "/path/to/doc2.pdf"],
///     query: "How do I authenticate?"
/// )
/// ```
func vectorStoreWorkflow(filePaths: [String], query: String) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    // Step 1: Upload files
    var fileIds: [String] = []
    for path in filePaths {
        let fileURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileURL)
        let uploaded = try await client.files.create(
            file: data,
            filename: fileURL.lastPathComponent,
            purpose: "assistants"
        )
        fileIds.append(uploaded.id)
        print("Uploaded: \(uploaded.id) (\(fileURL.lastPathComponent))")
    }

    // Step 2: Create a vector store with the files
    let store = try await client.vectorStores.create(
        name: "Example Knowledge Base",
        description: "Documentation for search demo",
        fileIds: fileIds,
        metadata: ["source": "advanced-examples"]
    )
    print("Created vector store: \(store.id) — status: \(store.status)")

    // Step 3: Wait for files to be indexed
    var currentStore = store
    while currentStore.status == "in_progress" {
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        currentStore = try await client.vectorStores.retrieve(store.id)
        print("Vector store status: \(currentStore.status)")
    }

    // Step 4: Add another file individually
    // (Demonstrates the vectorStores.files sub-resource)
    if let extraFileId = fileIds.first {
        let vsFile = try await client.vectorStores.files.retrieve(
            vectorStoreId: store.id,
            fileId: extraFileId
        )
        print("File \(vsFile.id) status in store: \(vsFile.status)")
    }

    // Step 5: Search the vector store
    let results = try await client.vectorStores.search(
        store.id,
        query: query,
        maxResults: 5
    )
    print("Search results for \"\(query)\":")
    for result in results.data {
        print("  - \(result.fileId) (score: \(result.score))")
    }

    // Cleanup
    try await client.vectorStores.delete(store.id)
    print("Deleted vector store \(store.id)")
}

// MARK: - Chunked Upload

/// Uploads a large file in chunks using the Uploads API.
///
/// Splits the file into parts of `chunkSize` bytes, uploads each part,
/// then completes the upload to produce a usable File object.
///
/// Usage:
/// ```swift
/// try await chunkedUpload(
///     filePath: "/path/to/large_training.jsonl",
///     purpose: "fine-tune",
///     chunkSize: 64 * 1024 * 1024  // 64 MB chunks
/// )
/// ```
func chunkedUpload(
    filePath: String,
    purpose: String = "fine-tune",
    chunkSize: Int = 64 * 1024 * 1024
) async throws {
    let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    let fileURL = URL(fileURLWithPath: filePath)
    let fileData = try Data(contentsOf: fileURL)
    let filename = fileURL.lastPathComponent

    // Step 1: Create the upload session
    let upload = try await client.uploads.create(
        filename: filename,
        purpose: purpose,
        bytes: fileData.count,
        mimeType: "application/jsonl"
    )
    print("Created upload: \(upload.id) — \(fileData.count) bytes total")

    // Step 2: Upload each chunk as a part
    var partIds: [String] = []
    var offset = 0

    while offset < fileData.count {
        let end = min(offset + chunkSize, fileData.count)
        let chunk = fileData[offset..<end]
        let partNumber = partIds.count + 1

        let part = try await client.uploads.parts.create(
            uploadId: upload.id,
            data: Data(chunk)
        )
        partIds.append(part.id)
        print("  Uploaded part \(partNumber): \(part.id) (\(chunk.count) bytes)")

        offset = end
    }

    // Step 3: Complete the upload
    let completed = try await client.uploads.complete(upload.id, partIds: partIds)
    print("Upload complete! Status: \(completed.status)")

    if let file = completed.file {
        print("File ready: \(file.id) (\(file.filename))")
    }
}

// MARK: - Custom Configuration

/// Demonstrates custom client configuration for Azure OpenAI, proxies,
/// or other non-default setups.
///
/// Shows how to set a custom base URL, timeout, and organization/project headers.
///
/// Usage:
/// ```swift
/// try await customConfiguration()
/// ```
func customConfiguration() async throws {
    // Azure OpenAI example
    let azureClient = OpenAI(
        apiKey: "your-azure-api-key",
        baseURL: URL(string: "https://your-resource.openai.azure.com/openai/deployments/your-deployment")!,
        timeoutInterval: 120
    )

    // Organization + project scoped client
    let orgClient = OpenAI(
        apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!,
        organization: "org-YourOrgId",
        project: "proj-YourProjectId",
        timeoutInterval: 300
    )

    // Proxy / self-hosted compatible endpoint
    let proxyClient = OpenAI(
        apiKey: "proxy-key",
        baseURL: URL(string: "http://localhost:8080/v1")!,
        timeoutInterval: 60
    )

    // Verify connectivity with a lightweight call
    let models = try await orgClient.models.list()
    print("Available models: \(models.data.count)")

    // Use the Azure client for chat
    let chatResponse = try await azureClient.chat.completions.create(
        model: "gpt-4o",
        messages: [.user("Hello from Azure!")]
    )
    print("Azure response: \(chatResponse.choices.first?.message.content ?? "")")

    // Use the proxy client for embeddings
    let embedding = try await proxyClient.embeddings.create(
        model: "text-embedding-3-small",
        input: .string("Test embedding via proxy")
    )
    print("Embedding dimensions: \(embedding.data.first?.embedding.count ?? 0)")
}
