# == Schema Information
#
# Table name: users
#
#  id                :integer          not null, primary key
#  name              :string(255)
#  email             :string(255)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  password_digest   :string(255)
#  remember_token    :string(255)
#  admin             :boolean          default(FALSE)
#  language          :string(255)
#  question_language :string(255)
#

class User < ActiveRecord::Base
  attr_accessible :name, :email, :password, :password_confirmation, :language, :question_language
  has_secure_password
  # the associating qns taken with the user
  has_many :takens, dependent: :destroy
  has_many :questions, through: :takens
  # does above line need a source: attribute?
  # no, bc default is sing._id = question_id which is correct value
  has_many :microposts, dependent: :destroy
  has_many :relationships, foreign_key: "follower_id", dependent: :destroy
  has_many :followed_users, through: :relationships, source: :followed
  has_many :reverse_relationships, 	foreign_key: 	"followed_id",
									class_name:		"Relationship",
									dependent: 		:destroy
  has_many :followers, through: :reverse_relationships, source: :follower
  
  
  before_save { |user| user.email = email.downcase }
  before_save :create_remember_token
  
  validates :name, presence: true, length: { maximum: 50 }
  validates :language, presence: true
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX },
					uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 6 }
  validates :password_confirmation, presence: true
  
  
  def following?(other_user)
	relationships.find_by_followed_id(other_user.id)
  end
	
  def follow!(other_user)
    relationships.create!(followed_id: other_user.id)
  end	
	
  def unfollow!(other_user)
	relationships.find_by_followed_id(other_user.id).destroy
  end

  def feed
    Micropost.from_users_followed_by(self)
  end

  # --------------------------------------
  # methods for taking questions
  
  # mark a completed quiz. i.e. create a taken record.
  def mark(took_quiz, is_correct)
    takens.create!(question_id: took_quiz.id, correct: is_correct)
  end
  
  # shows all questions taken
  def taken
    # @takens = Question.takens_taken(self)
	Taken.first
  end
  
  def question_languages
    "#{question_language}"
  end
  
  def sort_following_by_taken
    this_user = @current_user
	User.find_by_sql(
                    "SELECT fo_ed.id, fo_ed.name, fo_ed.email
                    FROM 
                      (
                      SELECT users.* from users
                      INNER JOIN relationships
                      ON users.id = followed_id
                      WHERE follower_id = (#{id})
                      ) fo_ed
                    LEFT JOIN takens
                    ON fo_ed.id = takens.user_id
                    GROUP BY fo_ed.id, fo_ed.name, fo_ed.email
                    ORDER BY count(takens.user_id) DESC"
					)
  end
  
  def sort_follower_by_taken
  this_user = @current_user
  User.find_by_sql(
                    "SELECT fo_ed.id, fo_ed.name, fo_ed.email
                    FROM 
                      (
                      SELECT users.* from users
                      INNER JOIN relationships
                      ON users.id = follower_id
                      WHERE followed_id = (#{id})
                      ) fo_ed
                    LEFT JOIN takens
                    ON fo_ed.id = takens.user_id
                    GROUP BY fo_ed.id, fo_ed.name, fo_ed.email
                    ORDER BY count(takens.user_id) DESC"
					)
  end
	  
	  
  private 
  
    def create_remember_token
      self.remember_token = SecureRandom.urlsafe_base64
    end
	

end
