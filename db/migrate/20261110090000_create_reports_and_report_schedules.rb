class CreateReportsAndReportSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :time_zone, :string, default: "UTC", null: false

    create_table :report_schedules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :restaurant, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :cadence, null: false
      t.time :run_at, null: false, default: "08:00"
      t.boolean :active, null: false, default: true
      t.datetime :next_run_at, null: false
      t.timestamps
    end
    add_index :report_schedules, [ :active, :next_run_at ]

    create_table :report_schedule_categories do |t|
      t.references :report_schedule, null: false, foreign_key: { on_delete: :cascade }
      t.string :category, null: false
      t.timestamps
    end
    add_index :report_schedule_categories, [ :report_schedule_id, :category ], unique: true,
      name: "index_report_schedule_categories_unique"

    create_table :report_schedule_recipients do |t|
      t.references :report_schedule, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :report_schedule_recipients, [ :report_schedule_id, :user_id ], unique: true,
      name: "index_report_schedule_recipients_unique"

    create_table :reports do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true
      t.references :restaurant, foreign_key: true
      t.references :report_schedule, foreign_key: { on_delete: :nullify }
      t.string :category, null: false
      t.string :status, null: false, default: "queued"
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.datetime :completed_at
      t.datetime :expires_at
      t.text :error_message
      t.timestamps
    end
    add_index :reports, [ :organization_id, :created_at ]
    add_index :reports, [ :restaurant_id, :created_at ]
    add_index :reports, [ :status, :expires_at ]

    create_table :report_deliveries do |t|
      t.references :report, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.datetime :emailed_at
      t.timestamps
    end
    add_index :report_deliveries, [ :report_id, :user_id ], unique: true,
      name: "index_report_deliveries_unique"
  end
end
