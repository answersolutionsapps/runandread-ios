//
//  BookTests.swift
//  RunAndReadTests
//
//  Created by Serge Nes on 2/3/25.
//

import Testing
@testable import RunAndRead
import Foundation
struct BookTests {
    
//    @Test func example() async throws {
//        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
//    }

    // Sample book data for testing
    var book: Book!

    init() {
        // Initialize the book object with test data
        let testText = [
            "This is a sample text for testing purposes.",
            "We will check the time and position calculations.",
            "This is a sample text for testing purposes.",
            "We will check the time and position calculations."
        ]
        book = Book(
            id: "testId",
            title: "Test Book",
            author: "Test Author",
            language: Locale(identifier: "en"),
            voiceIdentifier: nil,
            voiceRate: 1.0,
            text: testText,
            lastPosition: 15, // Arbitrary last position for testing
            created: Date(),
            bookmarks: []
        )
    }

    @Test func testCalculate() async throws {
        
//        it("calculates the total and progress time, and completion status") {
            // Simulate the calculation
            book.calculate {
                // Validate the progress time and total time are calculated correctly
                nprint(book.progressTime)
                nprint(book.totalTime)
                
                assert(book.progressTime == "00:06", "Progress time should be initially 0:00")
                assert(book.totalTime == "00:14", "Total time should be correctly formatted based on text length and voice rate")
                assert(book.isCompleted == false, "Book should not be completed at the start")
            }
//        }
    }

//    @Test func testApproximateLastPosition() async throws {
////        it("calculates the approximate last position based on elapsed time") {
//        let elapsedTime: Float = 6 // Arbitrary value to test
//        
////        let words: [String] = text
////                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
////                .filter { !$0.isEmpty }
//        //TODO: check it/test it!!!
//        let estimatedCharacters = elapsedTime / Book.SECONDS_PER_CHARACTER
//        
//        // Find the approximate word index
//        var characterCount = 0
//        for (index, word) in words.enumerated() {
//            characterCount += word.count + 1 // +1 for spaces
//            if characterCount >= estimatedCharacters {
//                return index
//            }
//        }
//            
//        let estimatedPosition = book.approximateLastPosition(from: elapsedTime)
//        nprint(estimatedPosition)
//            // Adjust the expected value based on your logic
//        let expectedPosition = 15
//        assert(estimatedPosition == expectedPosition, "The approximate position should be calculated correctly based on elapsed time.")
////        }
//    }

    @Test func testCalculateTotalTimeForCompletion() async throws {
//        it("calculates total time and marks the book as completed when lastPosition reaches the end of text") {
        let testText = [
            "This is a sample text for testing purposes.",
            "We will check the time and position calculations."
        ]
        let words: [String] = testText
                .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let book = Book(
                id: "testId2",
                title: "Complete Book",
                author: "Test Author",
                language: Locale(identifier: "en"),
                voiceIdentifier: nil,
                voiceRate: 1.0,
                text: ["This is a longer book text for testing."],
                lastPosition: words.count - 1,
                created: Date(),
                bookmarks: []
            )

            book.calculate {
                assert(book.isCompleted == true, "The book should be completed after reading all text")
            }
//        }
    }
}

