class String
    def trimzero
        self.sub(/^[0:]*/, "")
    end
end