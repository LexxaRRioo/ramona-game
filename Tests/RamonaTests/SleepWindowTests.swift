import Testing
@testable import Ramona

@Suite struct SleepWindowTests {
    @Test func simpleRangeContainsHoursInside() {
        let window = SleepWindow("01:00-08:00")!
        #expect(window.contains(hour: 1))
        #expect(window.contains(hour: 4.5))
        #expect(!window.contains(hour: 8))
        #expect(!window.contains(hour: 0.5))
        #expect(!window.contains(hour: 12))
    }

    @Test func wraparoundRangeCoversBothSidesOfMidnight() {
        let window = SleepWindow("22:00-06:00")!
        #expect(window.contains(hour: 23))
        #expect(window.contains(hour: 0))
        #expect(window.contains(hour: 5.99))
        #expect(!window.contains(hour: 6))
        #expect(!window.contains(hour: 12))
        #expect(!window.contains(hour: 21.99))
    }

    @Test func minutesAreParsedAsFractionalHours() {
        let window = SleepWindow("01:30-02:00")!
        #expect(abs(window.startHour - 1.5) < 0.0001)
        #expect(abs(window.endHour - 2.0) < 0.0001)
    }

    @Test func malformedStringsFailToParse() {
        #expect(SleepWindow("not-a-range") == nil)
        #expect(SleepWindow("01:00") == nil)
        #expect(SleepWindow("01:00-02:00-03:00") == nil)
        #expect(SleepWindow("ab:00-02:00") == nil)
    }
}
