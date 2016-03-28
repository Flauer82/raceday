json.array!(@racers) do |racer|
  json.extract! racer, :id, :number, :first_name, :last_name, :gender, :group, :secs
  json.url racer_url(racer, format: :json)
end
