# Automatically run AnnotateRb after migrations in development
# Configuration is in .annotaterb.yml

if Rails.env.development?
  # Hook into db:migrate to auto-annotate models
  Rake::Task["db:migrate"].enhance do
    puts "Annotating models..."
    system "bundle exec annotaterb models"
  end

  # Hook into db:rollback to update annotations
  Rake::Task["db:rollback"].enhance do
    puts "Annotating models..."
    system "bundle exec annotaterb models"
  end

  # Hook into db:schema:load to annotate
  Rake::Task["db:schema:load"].enhance do
    puts "Annotating models..."
    system "bundle exec annotaterb models"
  end
end
