class Racer
  include ActiveModel::Model

  #@id=doc[:_id].to_s
  #:_id =>BSON::ObjectId(@id)

  attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs

  #def to_s
  #  "#{@id}: #{@city}, #{@state}, pop=#{@population}"
  #end
  def persisted?
    !@id.nil?
  end
  def created_at
    nil
  end
  def updated_at
    nil
  end

  # initialize from both a Mongo and Web hash
  def initialize(params={})
    @id=params[:_id].nil? ? params[:id] : params[:_id].to_s
    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @gender=params[:gender]
    @group=params[:group]
    @secs=params[:secs].to_i
  end

  # convenience method for access to client in console
  def self.mongo_client
   Mongoid::Clients.default
  end

  # convenience method for access to zips collection
  def self.collection
   self.mongo_client['racers']
  end

  def self.all(prototype={}, sort={:num=>1}, offset=0, limit=nil)
    #map internal :population term to :pop document term
    tmp = {} #hash needs to stay in stable order provided
    sort.each {|k,v|
      k = k.to_sym==:num ? :number : k.to_sym
      tmp[k] = v  if [:first_name, :last_name, :number, :gender, :group, :secs].include?(k)
    }
    sort=tmp

    #convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:_id, :first_name, :last_name, :number, :gender, :group, :secs) if !prototype.nil?

    Rails.logger.debug {"getting all racers, prototype=#{prototype}, sort=#{sort}, offset=#{offset}, limit=#{limit}"}

    result=collection.find(prototype)
          .projection({_id:true, first_name:true, last_name:true, number:true, gender:true, group:true, secs:true})
          .sort(sort)
          .skip(offset)
    result=result.limit(limit) if !limit.nil?

    return result
  end

  def self.paginate(params)
    Rails.logger.debug("paginate(#{params})")
    page=(params[:page] ||= 1).to_i
    limit=(params[:per_page] ||= 30).to_i
    skip=(page-1)*limit
    sort=params[:sort] ||= {}

    #get the associated page of Zips -- eagerly convert doc to Zip
    racers=[]
    all(params, sort, skip, limit).each do |doc|
      racers << Racer.new(doc)
    end

    #get a count of all documents in the collection
    total=all(params, sort, 0, 1).count

    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(racers)
    end
  end

  # locate a specific document. Use initialize(hash) on the result to
  # get in class instance form
  def self.find id
    Rails.logger.debug {"getting racers #{id}"}

    @id = BSON::ObjectId(id)

    #if id.is_a? String
    #  @id = BSON::ObjectId(id)
    #else
    #  @id = id
    #end

    result=collection.find(:_id=>@id)
                  .projection({_id:true, first_name:true, last_name:true, number:true, gender:true, group:true, secs:true})
                  .first
    return result.nil? ? nil : Racer.new(result)
  end

  def save
    Rails.logger.debug {"saving #{self}"}

    result = self.class.collection.insert_one(_id:@id, first_name:@first_name, last_name:@last_name, number:@number, gender:@gender, group:@group, secs:@secs)
    @id=result.inserted_id
  end

  def update(params)
    Rails.logger.debug {"updating #{self} with #{params}"}
    #byebug

    @number=params[:number].to_i
    @first_name=params[:first_name]
    @last_name=params[:last_name]
    @gender=params[:gender]
    @group=params[:group]
    @secs=params[:secs].to_i

    params.slice!(:number, :first_name, :last_name, :gender, :group, :secs)# if !params.nil?

    self.class.collection
              .find(:_id => BSON::ObjectId.from_string(@id))
              .update_one(
                { :$set =>
                  {
                    number: @number,
                    first_name: @first_name,
                    last_name: @last_name,
                    gender: @gender,
                    group: @group,
                    secs: @secs
                  }
                }
              )
  end

  def destroy
    Rails.logger.debug {"destroying #{self}"}

    self.class.collection
              .find(:number => @number)
              .delete_one
  end

end
