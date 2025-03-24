# typed: false

require "spec_helper"

module CSVImporter
  describe ColumnDefinition do
    describe "#match?" do
      matcher :match do |name|
        match { |column_definition| column_definition.match?(name) }
      end

      subject { ColumnDefinition.new(name:, as:, to:) }
      let(:name) { nil }
      let(:as) { nil }
      let(:to) { nil }

      context "with email column" do
        let(:name) { :email }

        ["email", "Email", "EMAIL"].each do |name|
          it { should match(name) }
        end

        ["e-mail", "bob", nil].each do |name|
          it { should_not match(name) }
        end
      end

      context "with first name column" do
        let(:name) { :first_name }

        ["first name", "first_name", "First name"].each do |name|
          it { should match(name) }
        end

        ["first-name", "firstname"].each do |name|
          it { should_not match(name) }
        end
      end

      context "with first name column and as regex" do
        let(:name) { :first_name }
        let(:as) { /first.?name/i }

        ["first name", "first_name", "First name", "first-name", "Firstname"].each do |name|
          it { should match(name) }
        end

        ["lastname"].each do |name|
          it { should_not match(name) }
        end
      end

      context "with email column and as array" do
        let(:name) { :email }
        let(:as) { [:email, "courriel", /e.mail/i] }

        ["email", "Email", "EMAIL", "E-mail", "courriel", "Courriel"].each do |name|
          it { should match(name) }
        end
      end

      context "with email column and as hash" do
        let(:name) { :email }
        let(:as) { {not: :valid} }

        it "should raise an error" do
          expect { subject.match?("hello") }.to raise_error
        end
      end
    end
  end
end
