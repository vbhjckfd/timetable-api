class Route < ApplicationRecord

    has_and_belongs_to_many :stops

    TRAM = 1
    TROL = 2
    BUS = 3

end
