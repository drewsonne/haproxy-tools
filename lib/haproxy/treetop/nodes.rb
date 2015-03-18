module HAProxy
  module Treetop
    extend self

    # Include this module to always strip whitespace from the text_value
    module StrippedTextContent
      def content
        self.text_value.strip
      end
    end

    # Include this module if the node contains a config element.
    module ConfigBlockContainer
      def option_lines
        self.config_block.elements.select {|e| e.class == OptionLine}
      end

      def config_lines
        self.config_block.elements.select {|e| e.class == ConfigLine}
      end
    end

    # Include this module if the node contains a service address element.
    module ServiceAddressContainer
      def service_address
        self.elements.find {|e| e.class == ServiceAddress }
      end

      def host
        self.service_address.host.text_value.strip
      end

      def port
        self.service_address.port.text_value.strip
      end
    end

    # Include this module if the node contains a server elements.
    module ServerContainer
      def servers
        self.config_block.elements.select {|e| e.class == ServerLine}
      end
    end

    # Include this module if the value is optional for the node.
    module OptionalValueElement
      def value
        self.elements.find {|e| e.class == Value}
      end
    end

    class Whitespace < ::Treetop::Runtime::SyntaxNode
      def content
        self.text_value
      end
    end

    class LineBreak < ::Treetop::Runtime::SyntaxNode
    end

    class Char < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class Keyword < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class ProxyName < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class ServerName < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class Host < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class Port < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class Value < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class CommentText < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class ServiceAddress < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class CommentLine < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class BlankLine < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class ConfigLine < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
      include OptionalValueElement

      def key
        self.keyword.content
      end

      def attribute
        self.value.content
      end

    end

    class OptionLine < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
      include OptionalValueElement
    end

    class ServerLine < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
      include ServiceAddressContainer
      include OptionalValueElement

      def name
        self.server_name.content
      end
    end


    class GlobalHeader < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class DefaultsHeader < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
      def proxy_name
        self.elements.select {|e| e.class == ProxyName}.first
      end
    end

    class UserlistHeader < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class BackendHeader < ::Treetop::Runtime::SyntaxNode
      include StrippedTextContent
    end

    class FrontendHeader < ::Treetop::Runtime::SyntaxNode
      include ServiceAddressContainer
    end

    class ListenHeader < ::Treetop::Runtime::SyntaxNode
      include ServiceAddressContainer
    end

    class UserlistBlock < ::Treetop::Runtime::SyntaxNode

      def users
        self.elements.select {|e| e.class == UserLine}
      end

      def groups
        self.elements.select {|e| e.class == GroupLine}
      end

    end

    class UserLine < ::Treetop::Runtime::SyntaxNode
      def name
        self.elements[3].text_value
      end

      def groups
        if self.elements[6].empty?
          []
        else
          ;  #self.elements[6].text_value.slice!(' groups ').split(',')
        end
      end
    end

    class Password < Char
    end

    class PasswordType < ::Treetop::Runtime::SyntaxNode
    end

    class GroupLine < ::Treetop::Runtime::SyntaxNode
      def name
        self.elements[3].text_value
      end

      def users
        self.elements[4].empty? ? [] : Hash[*self.elements[4].elements[3].text_value.split(',').collect{ |key| [key, nil]}.flatten]
      end
    end

    class ConfigBlock < ::Treetop::Runtime::SyntaxNode
    end

    class DefaultsSection < ::Treetop::Runtime::SyntaxNode
      include ConfigBlockContainer
    end

    class GlobalSection < ::Treetop::Runtime::SyntaxNode
      include ConfigBlockContainer
    end

    class FrontendSection < ::Treetop::Runtime::SyntaxNode
      include ConfigBlockContainer
    end

    class ListenSection < ::Treetop::Runtime::SyntaxNode
      include ConfigBlockContainer
      include ServerContainer
    end

    class BackendSection < ::Treetop::Runtime::SyntaxNode
      include ConfigBlockContainer
      include ServerContainer
    end

    class UserlistSection < ::Treetop::Runtime::SyntaxNode

      GROUP = 0
      USER = 1

      def name
        self.userlist_header.proxy_name
      end

      def users
        self.elements[1].elements.select { |e| e.class == UserLine }
      end

      def group(group_name)
        self.elements[1].elements.select { |e|
            e.class == GroupLine && e.name == group_name
        }.find { |value| !value.nil? }
      end

      def user(user_name)
        self.elements[1].elements.select { |e|
          e.class == UserLine && e.name == user_name
        }.find { |value| !value.nil? }
      end

      def grouping
        # (+) Iterate through the users, and test how many have groups attached by number and percentage
        num_users_with_groups = self.userlist_block.users.select do |user|
          user.groups.length > 0
        end.length

        # (+) Iterate through the groups, and test how many have users attached by number and percentage
        num_groups_with_users = self.userlist_block.groups.select do |group|
          group.users.length > 0
        end.length

        # (+) if we have an exact match of users and groups, go by percentage.
        by_percentage = num_groups_with_users == num_users_with_groups

        users_comparitor = by_percentage ? num_users_with_groups/self.users.count : num_users_with_groups
        groups_comparitor = by_percentage ? num_groups_with_users/self.groups.count : num_groups_with_users

        if users_comparitor == groups_comparitor
          # If we still don't have a way to choose, sets groups in the group_line, instead of user_line
          GROUP
        elsif users_comparitor > groups_comparitor
          USER
        elsif users_comparitor < groups_comparitor
          GROUP
        end

      end
    end

    class ConfigurationFile < ::Treetop::Runtime::SyntaxNode
      def global
        self.elements.select {|e| e.class == GlobalSection}.first
      end

      def defaults
        self.elements.select {|e| e.class == DefaultsSection}
      end

      def listeners
        self.elements.select {|e| e.class == ListenSection}
      end

      def frontends
        self.elements.select {|e| e.class == FrontendSection}
      end

      def backends
        self.elements.select {|e| e.class == BackendSection}
      end

      def userlists
        self.elements.select {|e| e.class == UserlistSection}
      end
    end

    def print_node(e, depth, options = nil)
      options ||= {}
      options = {:max_depth => 2}.merge(options)

      puts if depth == 0
      print "--" * depth
      print " #{e.class.name.split('::').last}"
      print " [#{e.text_value}]" if e.class == ::Treetop::Runtime::SyntaxNode
      print " [#{e.content}]" if e.respond_to? :content
      puts
      e.elements.each do |child|
        print_node(child, depth + 1, options)
      end if depth < options[:max_depth] && e.elements && !e.respond_to?(:content)
    end
  end
end
