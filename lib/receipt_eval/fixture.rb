module ReceiptEval
  # One receipt in the eval: its source files in spec/fixtures/files/receipts
  # and its label in spec/fixtures/parsed_receipts -- the parse a perfect
  # parser would return, verified line by line against the receipt rather
  # than taken from a model.
  class Fixture
    LABEL_DIR = Rails.root.join("spec/fixtures/parsed_receipts")
    SOURCE_DIR = Rails.root.join("spec/fixtures/files/receipts")
    CONTENT_TYPES = {
      ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".png" => "image/png",
      ".pdf" => ReceiptParser::PDF_CONTENT_TYPE
    }.freeze
    UPLOAD_TRIES = 3

    def self.labeled
      Dir.glob(LABEL_DIR.join("*_parsed.json")).sort.map { |path| new(File.basename(path)[/\A\d+/]) }
    end

    attr_reader :id

    def initialize(id)
      @id = id.to_s
    end

    def label
      @label ||= JSON.parse(File.read(label_path), symbolize_names: true)
    end

    def label_path = LABEL_DIR.join("#{id}_parsed.json")

    # NNNN-receipt.jpg, or NNNN-receipt-1.jpg, NNNN-receipt-2.jpg... for a
    # receipt photographed in parts or several receipts on one check.
    def source_paths
      paths = Dir.glob(SOURCE_DIR.join("#{id}-receipt{,-*}.*")).sort
      raise ArgumentError, "No receipt files for fixture #{id} in #{SOURCE_DIR}" if paths.empty?

      paths
    end

    # The parser hands OpenAI URLs, so the files go up to Cloudinary and come
    # back through the delivery production uses (Check#receipt_parser_inputs).
    # Returns the parser inputs plus the public ids to destroy afterwards; if
    # one file fails, the ones already uploaded are destroyed before it raises.
    def upload
      uploads = []
      source_paths.each_with_index do |path, index|
        content_type = CONTENT_TYPES.fetch(File.extname(path).downcase)
        public_id = "licketysplit/receipt_eval/#{id}_#{index}_#{SecureRandom.hex(4)}"
        upload_file(path, public_id)
        uploads << [public_id, {url: delivery_url(public_id, content_type), content_type:}]
      end
      uploads
    rescue
      self.class.destroy_uploads(uploads.map(&:first))
      raise
    end

    def self.destroy_uploads(public_ids)
      public_ids.each { |public_id| Cloudinary::Uploader.destroy(public_id, resource_type: "image") }
    end

    def with_parser_inputs
      uploads = upload
      yield uploads.map(&:last)
    ensure
      self.class.destroy_uploads(uploads.map(&:first)) if uploads
    end

    private

    # An eval uploads every receipt in one go, and Cloudinary resets the odd
    # connection when it does; one dropped upload shouldn't sink the run.
    def upload_file(path, public_id)
      tries = 0
      begin
        Cloudinary::Uploader.upload(path, public_id:, resource_type: "image")
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError
        retry if (tries += 1) < UPLOAD_TRIES
        raise
      end
    end

    def delivery_url(public_id, content_type)
      if content_type == ReceiptParser::PDF_CONTENT_TYPE
        Cloudinary::Utils.cloudinary_url(public_id, resource_type: "image", format: "pdf")
      else
        Cloudinary::Utils.cloudinary_url(
          public_id, resource_type: "image", format: "jpg", **Check::RECEIPT_DELIVERY_TRANSFORMATION
        )
      end
    end
  end
end
