defmodule LivebookTest.ReportTest do
  use ExUnit.Case, async: true

  alias LivebookTest.{Report, Runner}

  defp make_result(attrs \\ []) do
    defaults = [
      notebook_path: "test.livemd",
      script_path: "test.exs",
      exit_status: 0,
      stdout: "",
      stderr: "",
      duration_ms: 100,
      timed_out: false
    ]

    struct!(Runner, Keyword.merge(defaults, attrs))
  end

  describe "build/1" do
    test "aggregates results correctly" do
      results = [
        make_result(notebook_path: "a.livemd"),
        make_result(notebook_path: "b.livemd", exit_status: 1, stderr: "fail")
      ]

      report = Report.build(results)

      assert report.total == 2
      assert report.passed == 1
      assert report.failed == 1
      assert report.duration_ms == 200
    end

    test "handles all passing results" do
      results = [make_result(), make_result()]

      report = Report.build(results)
      assert report.failed == 0
      assert report.failed_notebooks == []
    end

    test "handles all failing results" do
      results = [
        make_result(exit_status: 1, stderr: "err1"),
        make_result(exit_status: 2, stderr: "err2")
      ]

      report = Report.build(results)
      assert report.passed == 0
      assert report.failed == 2
    end

    test "handles empty results" do
      report = Report.build([])
      assert report.total == 0
      assert report.passed == 0
      assert report.failed == 0
    end
  end

  describe "format/1" do
    test "includes notebook count" do
      report = %Report{
        total: 3,
        passed: 2,
        failed: 1,
        duration_ms: 500,
        results: [],
        failed_notebooks: [make_result(exit_status: 1, stderr: "oops")],
        empty: false
      }

      output = Report.format(report)
      assert String.contains?(output, "3 notebooks")
      assert String.contains?(output, "2 passed")
      assert String.contains?(output, "1 failed")
    end

    test "shows success message when all pass" do
      report = %Report{
        total: 1,
        passed: 1,
        failed: 0,
        duration_ms: 100,
        results: [],
        failed_notebooks: [],
        empty: false
      }

      output = Report.format(report)
      assert String.contains?(output, "All notebooks passed")
    end

    test "includes failure details" do
      report = %Report{
        total: 1,
        passed: 0,
        failed: 1,
        duration_ms: 100,
        results: [],
        failed_notebooks: [
          make_result(notebook_path: "fail.livemd", exit_status: 1, stderr: "boom")
        ],
        empty: false
      }

      output = Report.format(report)
      assert String.contains?(output, "fail.livemd")
    end

    test "includes failure with empty stderr" do
      report = %Report{
        total: 1,
        passed: 0,
        failed: 1,
        duration_ms: 100,
        results: [],
        failed_notebooks: [
          make_result(notebook_path: "fail.livemd", exit_status: 1, stderr: "")
        ],
        empty: false
      }

      output = Report.format(report)
      assert String.contains?(output, "fail.livemd")
      assert String.contains?(output, "exit: 1")
    end
  end

  describe "exit_code/1" do
    test "returns 0 when all pass" do
      report = %Report{
        total: 2,
        passed: 2,
        failed: 0,
        duration_ms: 0,
        results: [],
        failed_notebooks: [],
        empty: false
      }

      assert Report.exit_code(report) == 0
    end

    test "returns 1 when any fail" do
      report = %Report{
        total: 2,
        passed: 1,
        failed: 1,
        duration_ms: 0,
        results: [],
        failed_notebooks: [],
        empty: false
      }

      assert Report.exit_code(report) == 1
    end

    test "returns 2 when no notebooks discovered" do
      report = %Report{
        total: 0,
        passed: 0,
        failed: 0,
        duration_ms: 0,
        results: [],
        failed_notebooks: [],
        empty: true
      }

      assert Report.exit_code(report) == 2
    end
  end

  describe "format/1 with empty discovery" do
    test "warns about empty discovery" do
      report = %Report{
        total: 0,
        passed: 0,
        failed: 0,
        duration_ms: 0,
        results: [],
        failed_notebooks: [],
        empty: true
      }

      output = Report.format(report)
      assert String.contains?(output, "0 notebooks found")
      assert String.contains?(output, "nothing to test")
    end
  end

  describe "format_verbose/1" do
    test "includes per-notebook details" do
      results = [make_result(notebook_path: "a.livemd", stdout: "output")]
      report = Report.build(results)

      output = Report.format_verbose(report)
      assert String.contains?(output, "a.livemd")
    end

    test "shows stdout when present" do
      results = [make_result(notebook_path: "a.livemd", stdout: "hello world")]
      report = Report.build(results)

      output = Report.format_verbose(report)
      assert String.contains?(output, "hello world")
    end

    test "shows stderr when present" do
      results = [
        make_result(notebook_path: "a.livemd", exit_status: 1, stderr: "error details")
      ]

      report = Report.build(results)
      output = Report.format_verbose(report)
      assert String.contains?(output, "error details")
    end

    test "omits stdout section when empty" do
      results = [make_result(notebook_path: "a.livemd", stdout: "")]
      report = Report.build(results)

      output = Report.format_verbose(report)
      assert String.contains?(output, "a.livemd")
      refute String.contains?(output, "stdout:")
    end

    test "omits stderr section when empty on success" do
      results = [make_result(notebook_path: "a.livemd", stderr: "")]
      report = Report.build(results)

      output = Report.format_verbose(report)
      assert String.contains?(output, "PASS")
      refute String.contains?(output, "stderr:")
    end
  end
end
