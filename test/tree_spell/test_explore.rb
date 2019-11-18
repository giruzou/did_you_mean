require "helper"
require "set"
require "yaml"
require_relative "human_typo"

# statistical tests on tree_spell algorithms
class ExploreTest < Test::Unit::TestCase
  N_REPEAT = 10_000

  MINI_DIRECTORIES = YAML.load_file(File.expand_path("../fixtures/mini_dir.yml", __dir__))
  RSPEC_DIRECTORIES = YAML.load_file(File.expand_path("../fixtures/rspec_dir.yml", __dir__))

  def test_checkers_with_many_typos_on_mini
    many_typos MINI_DIRECTORIES, "Minitest"
  end

  def test_checkers_with_many_typos_on_rspec
    many_typos RSPEC_DIRECTORIES, "Rspec"
  end

  def test_human_typo
    total_changes = 0
    word = "any_string_that_is_40_characters_long_sp"

    N_REPEAT.times do
      word_error = TreeSpell::HumanTypo.new(word).call
      total_changes += DidYouMean::Levenshtein.distance(word, word_error)
    end

    mean_changes = (total_changes.to_f / N_REPEAT).round(2)

    puts "\nHumanTypo mean_changes: #{mean_changes} with n_repeat: #{N_REPEAT}"
    puts "Expected  mean_changes: 2.1 with n_repeat: 10000, plus/minus 0.03\n"
  end

  def test_execution_speed
    puts "\nTesting execution time of Standard"

    measure_execution_speed do |files, error|
      DidYouMean::SpellChecker.new(dictionary: files).correct(error)
    end

    puts "\nTesting execution time of Tree"

    measure_execution_speed do |files, error|
      DidYouMean::TreeSpellChecker.new(dictionary: files).correct(error)
    end

    puts "\nTesting execution time of Augmented Tree"

    measure_execution_speed do |files, error|
      DidYouMean::TreeSpellChecker.new(dictionary: files, augment: true).correct(error)
    end
  end

  private

  def measure_execution_speed
    len = RSPEC_DIRECTORIES.length

    time_ms =
      Benchmark.measure do
        N_REPEAT.times do
          word = RSPEC_DIRECTORIES[rand len]
          word_error = TreeSpell::HumanTypo.new(word).call

          yield RSPEC_DIRECTORIES, word_error
        end
      end.real

    puts "Average time (ms): #{time_ms.round(1)}"
  end

  def many_typos(files, title)
    first_times = [0, 0, 0]
    total_suggestions = [0, 0, 0]
    total_failures = [0, 0, 0]
    len = files.length

    N_REPEAT.times do
      word = files[rand len]
      word_error = TreeSpell::HumanTypo.new(word).call
      suggestions_a = group_suggestions word_error, files

      check_first_is_right(word, suggestions_a, first_times)
      check_no_suggestions(suggestions_a, total_suggestions)
      check_for_failure(word, suggestions_a, total_failures)
    end

    print_results(first_times, total_suggestions, total_failures, title)
  end

  def group_suggestions(word_error, files)
    a0 = DidYouMean::TreeSpellChecker.new(dictionary: files).correct(word_error)
    a1 = DidYouMean::SpellChecker.new(dictionary: files).correct(word_error)
    a2 = a0.empty? ? a1 : a0

    [a0, a1, a2]
  end

  def check_for_failure(word, suggestions_a, total_failures)
    suggestions_a.each_with_index do |a, i|
      total_failures[i] += 1 unless a.include? word
    end
  end

  def check_first_is_right(word, suggestions_a, first_times)
    suggestions_a.each_with_index do |a, i|
      first_times[i] += 1 if word == a.first
    end
  end

  def check_no_suggestions(suggestions_a, total_suggestions)
    suggestions_a.each_with_index do |a, i|
      total_suggestions[i] += a.length
    end
  end

  def print_results(first_times, total_suggestions, total_failures, title)
    algorithms = ["Tree     ", "Standard ", "Augmented"]

    print_header title

    (0..2).each do |i|
      ft = (first_times[i].to_f / N_REPEAT * 100).round(1)
      mns = (total_suggestions[i].to_f / (N_REPEAT - total_failures[i])).round(1)
      f = (total_failures[i].to_f / N_REPEAT * 100).round(1)

      puts " #{algorithms[i]}  #{" " * 7}  #{ft} #{" " * 14} #{mns} #{" " * 15} #{f} #{" " * 16}"
    end
  end

  def print_header(title)
    puts "#{" " * 30} #{title} Summary #{" " * 31}"
    puts "-" * 80
    puts " Method  |   First Time (\%)    Mean Suggestions       Failures (\%) #{" " * 13}"
    puts "-" * 80
  end
end
