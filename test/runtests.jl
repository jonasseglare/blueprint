# https://towardsdatascience.com/how-to-test-your-software-with-julia-4050379a9f3

# Run tests either by
#  1. C-c C-b from emacs
#  2. Command line: julia test/runtests.jl

using Test

include("../src/Blueprint.jl") # Alternative 1
#using Blueprint               # Alternative 2: Does not reload changes in REPL

using FunctionalCollections
using LinearAlgebra

# Not needed:
#import .Blueprint


@testset "Plane tests" begin
    @test Blueprint.plane_at_pos([1, 2, 3], [3, 3, 7]).offset == 30.0

    plane = Blueprint.plane_at_pos([1, 2, 3], [10, 11, 12])

    @test plane.normal[1] == 1.0
    @test plane.normal[2] == 2.0
    @test plane.offset == 68.0
    @test Blueprint.evaluate(plane, [10, 11, 12]) == 0.0
    @test Blueprint.evaluate(plane, [11, 13, 15]) == 14.0
    @test Blueprint.evaluate(plane, [9, 9, 9]) == -14.0
end

@testset "Plane intersection" begin
    bp = Blueprint
    a = bp.Plane([1.0, 0.0, 0.0], 0.0)
    b = bp.Plane([0.0, 1.0, 0.0], 0.0)
    line = bp.intersect(a, b)
    @test norm(line.dir - [0, 0, 1.0]) < 1.0e-6
    @test norm(line.pos - [0, 0, 0]) < 1.0e-6
end

@testset "Plane intersection 2" begin
    bp = Blueprint
    a = bp.plane_at_pos([-1.0, 2.0, 0.0], [0.0, 0.0, 0.0])
    b = bp.plane_at_pos([10.0, 0.0, 0.0], [2.0, 0.0, 0.0])
    line = bp.intersect(b, a)
    @test line.dir[1] == 0.0
    @test line.dir[2] == 0.0
    @test 0 < line.dir[3]
    @test norm(line.pos - [2.0, 1.0, 0.0]) < 1.0e-6
end

@testset "Plane shadowing" begin
    bp = Blueprint    
    @test bp.shadowed_by(bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 3.0]),
                         bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 4.0]))
    @test !bp.shadowed_by(bp.plane_at_pos([0.0, 0.0, 1.001], [0.0, 0.0, 3.0]),
                          bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 4.0]))
    @test !bp.shadowed_by(bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 4.0]),
                          bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 3.0]))
end

@testset "Polyhedron tests" begin
    bp = Blueprint
    planes = @Persistent Dict(:a => bp.plane_at_pos([0.0, 1.0, 0.0], [0.0, 0.0, 0.0]),
                              :b => bp.plane_at_pos([1.0, 0.0, 0.0], [0.0, 0.0, 0.0]),
                              :c => bp.plane_at_pos([-1.0, -1.0, 0.0], [0.5, 0.5, 0.0]))
    polyhedron = bp.polyhedron_from_planes(planes)

    @test 3 == length(polyhedron.planes)
    @test 3 == length(polyhedron.bounded_lines)
    @test 0 == length(polyhedron.corners)
end

@testset "Polyhedron tests 2" begin
    bp = Blueprint
    planes = @Persistent Dict(:x => bp.plane_at_pos([1.0, 0.0, 0.0], [0.0, 0.0, 0.0]),
                              :y => bp.plane_at_pos([0.0, 1.0, 0.0], [0.0, 0.0, 0.0]),
                              :z => bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 0.0]),
                              :xyz => bp.plane_at_pos([-1.0, -1.0, -1.0], [1.0, 0.0, 0.0]))
                              
    polyhedron = bp.polyhedron_from_planes(planes)

    @test 4 == length(polyhedron.planes)
    @test 6 == length(polyhedron.bounded_lines)
    @test 4 == length(polyhedron.corners)

    @test [0.0, 0.0, 0.0] == polyhedron.corners[(:x, :y, :z)]
    @test [0.0, 0.0, 1.0] == polyhedron.corners[(:x, :xyz, :y)]
end

@testset "Beam tests" begin
    specs = Blueprint.BeamSpecs(1, 3)
    f = Blueprint.beam_factory("Mjao", specs)
    beam = Blueprint.new_beam!(f)
    @test beam.name == "Mjao0"
    @test f.counter == 1
end

@testset "Half-space test" begin
    bp = Blueprint
    plane = bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 0.5])
    @test bp.inside_halfspace(plane, [100.0, -2220.0, 0.6])
    @test !(bp.inside_halfspace(plane, [100.0, -2220.0, 0.4]))
end

@testset "Ordered pair test" begin
    @test Blueprint.ordered_pair(:a, :b) == (:a, :b)
    @test Blueprint.ordered_pair(:b, :a) == (:a, :b)
end

@testset "Test plane/line intersection" begin
    bp = Blueprint
    @test bp.intersect(bp.plane_at_pos([0.0, 0.0, -1.0], [0.0, 0.0, 3.5]),
                       bp.ParameterizedLine([0.0, 0.0, 0.5], [0.0, 0.0, 0.0])).lambda == 7.0
    @test !bp.exists(
        bp.intersect(bp.plane_at_pos([0.0, 0.0, -1.0], [0.0, 0.0, 3.5]),
                     bp.ParameterizedLine([0.0, 3.0, 0.0], [0.0, 0.0, 0.0])))

end

@testset "Update line bounds test" begin
    bp = Blueprint

    ps = bp.default_polyhedron_settings()
    
    line = bp.ParameterizedLine([0.0, 0.0, 1.0], [0.0, 0.0, 0.0])
    bds = bp.initialize_line_bounds(line)

    A = 

    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([-1.0, 0.0, -1.0], [2.0, 0.0, 0.0]))

    @test bds.exists
    @test bds.lower == nothing
    @test bds.upper.value == 2.0

    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([-1.0, 0.0, -1.0], [3.0, 0.0, 0.0]))
    
    @test bds.exists
    @test bds.lower == nothing
    @test bds.upper.value == 2.0
    
    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([-1.0, 0.0, -1.0], [1.0, 0.0, 0.0]))
    
    @test bds.exists
    @test bds.lower == nothing
    @test bds.upper.value == 1.0

    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 1.0], [-4.5, 0.0, 0.0]))

    @test bds.exists
    @test bds.lower.value == -4.5
    @test bds.upper.value == 1.0

    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 1.0], [-4.6, 0.0, 0.0]))
    
    @test bds.exists
    @test bds.lower.value == -4.5
    @test bds.upper.value == 1.0
    
    bds = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 1.0], [-4.1, 0.0, 0.0]))
    
    @test bds.exists
    @test bds.lower.value == -4.1
    @test bds.upper.value == 1.0

    bds0 = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 1.0], [10.0, 0.0, 0.0]))

    @test !bds0.exists

    bds1 = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 0.0], [-10.0, 0.0, 0.0]))

    @test bds == bds1
    
    bds2 = bp.update_line_bounds(
        bds,
        :x,
        bp.plane_at_pos([1.0, 0.0, 0.0], [10.0, 0.0, 0.0]))

    @test !bds2.exists
end

@testset "Plane transforms" begin
    bp = Blueprint
    plane = bp.plane_at_pos([0.0, 1.0, 0.0], [2.0, 1.0, 0.0])

    # Try both rotation and translation, separately
    plane2 = bp.transform(bp.rigid_transform_from_xy_rotation(0.5*pi, 3), plane)
    @test isapprox(plane2.normal, [-1.0, 0.0, 0.0], atol=1.0e-6)
    @test isapprox(plane2.offset, 1.0, atol=1.0-6)

    plane3 = bp.transform(bp.rigid_transform_from_translation([0.5, 3.4, 0.0]), plane)
    @test plane3.normal == [0.0, 1.0, 0.0]
    @test plane3.offset == 4.4
end

@testset "Test add planes" begin
    bp = Blueprint
    base_poly = bp.polyhedron_from_planes(Dict(:x => bp.plane_at_pos([1.0, 0.0, 0.0], [0.0, 0.0, 0.0]),
                                               :y => bp.plane_at_pos([0.0, 1.0, 0.0], [0.0, 0.0, 0.0]),
                                               :z => bp.plane_at_pos([0.0, 0.0, 1.0], [0.0, 0.0, 0.0])))
    @test 1 == length(base_poly.corners)
    polyhedron = bp.add_planes(base_poly, Dict(:xyz => bp.plane_at_pos([-1.0, -1.0, -1.0], [1.0, 0.0, 0.0])))
    @test 4 == length(polyhedron.corners)
    @test [0.0, 1.0, 0.0] == polyhedron.corners[(:x, :xyz, :z)]

    tpoly = bp.transform(bp.rigid_transform_from_xy_rotation(0.5*pi, 3), polyhedron)
    @test isapprox([-1.0, 0.0, 0.0], tpoly.corners[(:x, :xyz, :z)], atol=1.0e-6)
end

@testset "Test flip" begin
    bp = Blueprint
    plane = bp.plane_at_pos([3, 0.5, 0.25], [-3.0, 0.0, -4.0])
    plane2 = bp.flip(plane)

    X = [9.0, 4.7, 2.0]
    @test bp.evaluate(plane, X) == -bp.evaluate(plane2, X)
end
