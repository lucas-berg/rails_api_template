# frozen_string_literal: true

class DocumentPolicy
  def initialize(user, document, team)
    @user = user
    @document = document
    @team = team
  end

  def allowed?(action)
    return false unless membership && @document.team_id == @team.id
    return true if %i[read download preview].include?(action)
    return false if membership.viewer?

    write_allowed?(action)
  end

  private

  # :reek:ControlParameter -- Actions are deliberately checked against a fixed permission whitelist.
  def write_allowed?(action)
    own_upload = @document.uploader_id == @user.id
    case action
    when :create then true
    when :complete, :avatar then own_upload
    when :remove then own_upload || membership.owner? || membership.admin?
    else false
    end
  end

  def membership
    return unless @team.accessible? && @user&.active_for_authentication? && @user.confirmed?
    return @membership if defined?(@membership)

    @membership = @team.active_members.find_by(user_id: @user.id)
  end
end
