# Idempotent seed for Marina MVP
# Creates: 1 org, 2 locations (Browns Bay + Maxwell) with hours and slips,
# 5 default request types, and an initial manager (env-configurable).

ORG = Organization.find_or_create_by!(slug: "marina") { |o| o.name = "Marina" }

# ---- Locations ----
LOCATIONS = [
  { slug: "browns-bay", name: "Browns Bay", address: "Browns Bay Marina", timezone: "America/Chicago", soft_cap: 6, dry: 20, wet: 10,
    pushover_group_key: "gawgufnpjp7315b5hrmdbdnsri1vm2" },
  { slug: "maxwell",    name: "Maxwells",   address: "Maxwell Marina",    timezone: "America/Chicago", soft_cap: 6, dry: 20, wet: 10,
    pushover_group_key: "gntoi5u6qub17xf4h8bq1ajofsfkyk" }
]

LOCATIONS.each do |attrs|
  loc = ORG.locations.find_or_initialize_by(slug: attrs[:slug])
  loc.assign_attributes(
    name: attrs[:name],
    address: attrs[:address],
    timezone: attrs[:timezone],
    soft_cap_per_hour: attrs[:soft_cap],
    pushover_group_key: attrs[:pushover_group_key],
    is_active: true
  )
  loc.save!

  # Hours: 7am-6pm weekdays (Mon-Fri = 1..5), 7am-4pm weekends (Sat=6, Sun=0)
  (0..6).each do |dow|
    open_t  = "07:00"
    close_t = (1..5).include?(dow) ? "18:00" : "16:00"
    h = loc.location_hours.find_or_initialize_by(day_of_week: dow)
    h.update!(open_time: open_t, close_time: close_t, closed: false)
  end

  # Slips
  (1..attrs[:dry]).each do |i|
    loc.slips.find_or_create_by!(label: format("D-%02d", i)) { |s| s.slip_type = "dry" }
  end
  (1..attrs[:wet]).each do |i|
    loc.slips.find_or_create_by!(label: format("W-%02d", i)) { |s| s.slip_type = "in_water" }
  end
end

# ---- Request types ----
TYPES = [
  { slug: "launch",    name: "Launch",     icon: "🚤", color: "#2563eb", storage: %w[dry],            requires_desc: false, sort: 10 },
  { slug: "fuel",      name: "Fuel",       icon: "⛽", color: "#d97706", storage: %w[dry in_water],   requires_desc: false, sort: 20 },
  { slug: "cover-off", name: "Cover Off",  icon: "🔓", color: "#0d9488", storage: %w[dry in_water],   requires_desc: false, sort: 30 },
  { slug: "cover-on",  name: "Cover On",   icon: "🔒", color: "#0d9488", storage: %w[dry in_water],   requires_desc: false, sort: 40 },
  { slug: "misc",      name: "Misc",       icon: "🛠️", color: "#6b7280", storage: %w[dry in_water],   requires_desc: true,  sort: 90 }
]

TYPES.each do |t|
  rt = ORG.request_types.find_or_initialize_by(slug: t[:slug])
  rt.assign_attributes(
    name: t[:name],
    icon: t[:icon],
    color: t[:color],
    applicable_storage_types: t[:storage],
    requires_description: t[:requires_desc],
    sort_order: t[:sort],
    is_active: true
  )
  rt.save!
end

# ---- Initial manager ----
mgr_email = ENV.fetch("SEED_MANAGER_EMAIL", "northshoremarinaapp@gmail.com")
mgr_name  = ENV.fetch("SEED_MANAGER_NAME", "Marina Manager")

manager = ORG.users.find_or_initialize_by(email: mgr_email)
manager.assign_attributes(name: mgr_name, role: :manager, is_active: true)

# Optionally set the manager's password from env. Idempotent:
# - SEED_MANAGER_PASSWORD set → adopt it (so rotating the env var rotates the password)
# - Not set + manager has no password yet → generate a one-shot random password,
#   set it, and print to stdout so a deploy operator can capture it from logs.
# - Not set + manager already has a password → leave it alone.
provided_pw = ENV["SEED_MANAGER_PASSWORD"].presence
generated_pw = nil
if provided_pw
  manager.password = provided_pw
elsif manager.password_digest.blank?
  generated_pw = SecureRandom.urlsafe_base64(18)
  manager.password = generated_pw
end

manager.save!

# ---- Development convenience users (only outside production) ----
# These match the "Dev quick-login" panel on /login. Safe to leave in
# staging/test environments — gated below before login is exposed.
unless Rails.env.production?
  helper = ORG.users.find_or_initialize_by(email: "helper@example.com")
  helper.assign_attributes(name: "Hannah Helper", role: :helper, is_active: true,
                            venmo_handle: "@hannahhelper")
  helper.save!

  customer = ORG.users.find_or_initialize_by(email: "customer@example.com")
  customer.assign_attributes(name: "Casey Customer", role: :customer, is_active: true,
                              phone: "555-010-0001")
  customer.save!

  browns_bay = ORG.locations.find_by(slug: "browns-bay")
  maxwell    = ORG.locations.find_by(slug: "maxwell")

  customer.boats.find_or_create_by!(name: "Sea Star") do |b|
    b.location = browns_bay
    b.storage_type = "in_water"
    b.make = "Bayliner"
    b.model = "DX2050"
    b.year = 2019
    b.length_ft = 20.0
    b.slip = browns_bay.slips.find_by(slip_type: "in_water", label: "W-01")
  end

  customer.boats.find_or_create_by!(name: "Mountain Mist") do |b|
    b.location = maxwell
    b.storage_type = "dry"
    b.make = "Crestliner"
    b.model = "1750 Fish Hawk"
    b.year = 2021
    b.length_ft = 17.5
    b.slip = maxwell.slips.find_by(slip_type: "dry", label: "D-01")
  end
end

puts "✓ Seeded org '#{ORG.name}' with #{ORG.locations.count} locations, " \
     "#{ORG.locations.sum { |l| l.slips.count }} slips, " \
     "#{ORG.request_types.count} request types"
puts "  Manager:  #{manager.email}"
if generated_pw
  puts ""
  puts "  ┌─────────────────────────────────────────────────────────────┐"
  puts "  │ Generated initial admin password (save this — shown once):   │"
  puts "  │   #{generated_pw.ljust(58)}│"
  puts "  │ Set SEED_MANAGER_PASSWORD in env to override on future deploys│"
  puts "  └─────────────────────────────────────────────────────────────┘"
  puts ""
elsif provided_pw
  puts "  Password: (set from SEED_MANAGER_PASSWORD env var)"
end
unless Rails.env.production?
  puts "  Helper:   helper@example.com"
  puts "  Customer: customer@example.com (2 boats)"
end
