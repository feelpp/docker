/* -*- mode: c++; coding: utf-8; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4; show-trailing-whitespace: t  -*-

  This file is part of the Feel library

  Author(s): Christophe Prud'homme <christophe.prudhomme@ujf-grenoble.fr>
             Abdoulaye Samake <Abdoulaye.Samake@imag.fr>
       Date: 2011-08-24

  Copyright (C) 2011 Université Joseph Fourier (Grenoble I)

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/
/**
   \file mortar.cpp
   \author Christophe Prud'homme <christophe.prudhomme@ujf-grenoble.fr>
   \author Abdoulaye Samake <Abdoulaye.Samake@imag.fr>
   \date 2011-08-24
 */
#if !defined( __FEELPP_BENCH_MORTAR_HPP)
#define __FEELPP_BENCH_MORTAR_HPP 1

#include <boost/any.hpp>
#include <boost/utility.hpp>
#include <google/profiler.h>

#include <feel/options.hpp>
#include <feel/feelcore/simget.hpp>
#include <feel/feelalg/backend.hpp>
#include <feel/feeldiscr/functionspace.hpp>
#include <feel/feeldiscr/region.hpp>
#include <feel/feelfilters/gmsh.hpp>
#include <feel/feelfilters/exporter.hpp>
#include <feel/feelvf/vf.hpp>
#include <feel/feelfilters/geotool.hpp>
#include <feel/feelpoly/lagrange.hpp>
#include <feel/feelalg/matrixblock.hpp>
#include <boost/assign/list_of.hpp>
#include <boost/assign/std/vector.hpp>
#include <boost/assign/std/vector.hpp>

namespace Feel
{
/**
 * \class Mortar
 *
 * Mortar Solver using continuous approximation spaces
 * solve \f$ -\Delta u = f\f$ on \f$\Omega\f$ and \f$u= g\f$ on \f$\Gamma\f$
 *
 * \tparam Dim the geometric dimension of the problem (e.g. Dim=2 or 3)
 */
template<int Dim, int Order1, int Order2>
class Mortar
    :
    public Simget
{
    typedef Simget super;
public:

    typedef double value_type;

    typedef Backend<value_type> backend_type;

    typedef boost::shared_ptr<backend_type> backend_ptrtype;

    typedef typename backend_type::sparse_matrix_type sparse_matrix_type;

    typedef typename backend_type::vector_type vector_type;

    typedef Simplex<Dim> convex_type;

    typedef Mesh<convex_type> mesh_type;

    typedef boost::shared_ptr<mesh_type> mesh_ptrtype;

    typedef typename mesh_type::trace_mesh_type trace_mesh_type;

    typedef typename mesh_type::trace_mesh_ptrtype trace_mesh_ptrtype;

    typedef bases<Lagrange<Order1,Scalar> > basis1_type;

    typedef bases<Lagrange<Order2,Scalar> > basis2_type;

    typedef FunctionSpace<mesh_type, basis1_type> space1_type;

    typedef FunctionSpace<mesh_type, basis2_type> space2_type;

    typedef boost::shared_ptr<space1_type> space1_ptrtype;

    typedef boost::shared_ptr<space2_type> space2_ptrtype;

    typedef typename space1_type::trace_functionspace_type lagmult_space_type;

    typedef typename boost::shared_ptr<lagmult_space_type> lagmult_space_ptrtype;

    typedef typename space1_type::element_type element1_type;

    typedef typename space2_type::element_type element2_type;

    typedef typename lagmult_space_type::element_type trace_element_type;

    typedef Exporter<mesh_type> export_type;

    typedef boost::shared_ptr<export_type> export_ptrtype;

    typedef Exporter<trace_mesh_type> trace_export_type;

    typedef boost::shared_ptr<trace_export_type> trace_export_ptrtype;

    /**
     * Constructor
     */
    Mortar( std::string const& basis_name, Feel::po::variables_map const& vm, AboutData const& ad )
        :
        super( vm, ad ),
        // timers(),
        M_backend(),
        M_basis_name( basis_name )
    {}

    std::string name() const { return M_basis_name; }

    void run();

    void run( const double* X, unsigned long P, double* Y, unsigned long N ) { run(); }

private:

    std::string M_basis_name;
    //! linear algebra backend
    backend_ptrtype M_backend;
    // std::map<std::string, std::pair<boost::timer, double> > timers;
    // flags for outsides
    // std::vector<int> outside1;
    // std::vector<int> outside2;
    // marker for interfaces
    // int gamma1;
    // int gamma2;
}; // Mortar

template<int Dim, int Order1, int Order2>
void
Mortar<Dim, Order1, Order2>::run()
{
    using namespace Feel::vf;

    if ( this->vm().count( "nochdir" ) == false )
    {
        this->changeRepository( boost::format( "perf/%1%/%2%/%3%/h_%4%/" )
                                % this->about().appName()
                                % convex_type::name()
                                % M_basis_name
                                % meshSize() );
    }

    M_backend =  backend_type::build( this->vm() ) ;

#if defined(KOVASZNAY)
    double x1min = -0.5, x1max=1;
    double x2min = 1, x2max=1.5;
    double ymin =  0, ymax=1;
    double zmin = 0, zmax=1;
#else
    double x1min = 0, x1max=0.5;
    double x2min = 0.5, x2max=1;
    double ymin = 0, ymax=1;
    double zmin = 0, zmax=1;
#endif

    double shear = this->vm()["shear"].template as<value_type>();
    bool recombine = this->vm()["recombine"].template as<bool>();

    //  boost::timer t;


    auto mesh1 = createGMSHMesh( _mesh=new mesh_type,
                                 _update=MESH_CHECK|MESH_UPDATE_FACES|MESH_UPDATE_EDGES|MESH_RENUMBER,
                                 _desc=domain( _name= (boost::format( "%1%-%2%-%3%" ) % "hypercube" % Dim % 1).str() ,
                                               _shape="hypercube",
                                               _addmidpoint=false,
                                               _usenames=false,
                                               _convex=((!recombine)&&convex_type::is_hypercube)?"Hypercube":"Simplex",
                                               _recombine=(recombine&&convex_type::is_hypercube), // generate quads which are not regular
                                               _dim=Dim,
                                               _h=M_meshSize,
                                               _shear=shear,
                                               _xmin=x1min,_xmax=x1max,
                                               _ymin=ymin,_ymax=ymax,
                                               _zmin=zmin,_zmax=zmax ) );

    auto mesh2 = createGMSHMesh( _mesh=new mesh_type,
                                 _update=MESH_CHECK|MESH_UPDATE_FACES|MESH_UPDATE_EDGES|MESH_RENUMBER,
                                 _desc=domain( _name= (boost::format( "%1%-%2%-%3%" ) % "hypercube" % Dim % 1).str() ,
                                               _shape="hypercube",
                                               _addmidpoint=false,
                                               _usenames=false,
                                               _convex=((!recombine)&&convex_type::is_hypercube)?"Hypercube":"Simplex",
                                               _recombine=(recombine&&convex_type::is_hypercube), // generate quads which are not regular
                                               _dim=Dim,
                                               _h=M_meshSize,
                                               _shear=shear,
                                               _xmin=x2min,_xmax=x2max,
                                               _ymin=ymin,_ymax=ymax,
                                               _zmin=zmin,_zmax=zmax ) );


    //M_stats.put("t.init.mesh",t.elapsed());t.restart();

     std::vector<int> outside1;
     std::vector<int> outside2;
     int gamma1;
     int gamma2;

     std::map<std::string, std::pair<boost::timer, double> > timers;

    if ( Dim == 2 )
    {
        using namespace boost::assign;
        outside1 += 1,2,4;
        outside2 += 2,3,4;
        gamma1 = 3;
        gamma2 = 1;
    }
    else if( Dim == 3 )
    {
        using namespace boost::assign;
        outside1 += 6,15,19,23,28;
        outside2 += 6,15,23,27,28;
        gamma1 = 27;
        gamma2 = 19;
    }

    auto Xh1 = space1_type::New( mesh1 );
    auto u1 = Xh1->element();
    auto v1 = Xh1->element();

    auto trace_mesh = mesh1->trace( markedfaces(mesh1,gamma1) );
    lagmult_space_ptrtype Lh1 = lagmult_space_type::New( trace_mesh );
    auto mu = Lh1->element();
    auto nu = Lh1->element();

    auto Xh2 = space2_type::New( mesh2 );
    auto u2 = Xh2->element();
    auto v2 = Xh2->element();

    value_type pi = M_PI;
    auto g = sin(pi*Px())*cos(pi*Py())*cos(pi*Pz());

    auto gradg = trans( +pi*cos(pi*Px())*cos(pi*Py())*cos(pi*Pz())*unitX()
                        -pi*sin(pi*Px())*sin(pi*Py())*cos(pi*Pz())*unitY()
                        -pi*sin(pi*Px())*cos(pi*Py())*sin(pi*Pz())*unitZ() );

    auto f = pi*pi*Dim*g;

    bool weakdir = this->vm()["weakdir"].template as<int>();
    value_type penaldir = this->vm()["penaldir"].template as<double>();
    value_type coeff = this->vm()["coeff"].template as<double>();

    auto F1 = M_backend->newVector( Xh1 );
    form1( _test=Xh1, _vector=F1, _init=true ) =
        integrate( elements(mesh1), f*id(v1) );

    BOOST_FOREACH( int marker, outside1 )
    {
        form1( _test=Xh1, _vector=F1 ) +=
            integrate( markedfaces(mesh1,marker),
                       g*(-grad(v1)*vf::N()+penaldir*id(v1)/hFace()) );
    }

    F1->close();

    auto D1 = M_backend->newMatrix( Xh1, Xh1 );

    form2( _trial=Xh1, _test=Xh1, _matrix=D1, _init=true ) =
        integrate( elements(mesh1), coeff*gradt(u1)*trans(grad(v1)) );

    BOOST_FOREACH( int marker, outside1 )
    {
        form2( _trial=Xh1, _test=Xh1, _matrix=D1 ) +=
            integrate( markedfaces(mesh1,marker),
                       -(gradt(u1)*vf::N())*id(v1)
                       -(grad(v1)*vf::N())*idt(u1)
                       +penaldir*id(v1)*idt(u1)/hFace());
    }

    D1->close();

    auto B1 = M_backend->newMatrix( Xh1, Lh1 );

    Log() << "init_B1 starts\n";
    timers["init_B1"].first.restart();

    form2( _trial=Xh1, _test=Lh1, _matrix=B1, _init=true );

    timers["init_B1"].second = timers["init_B1"].first.elapsed();
    Log() << "init_B1 done in " << timers["init_B1"].second << "s\n";

    form2( _trial=Xh1, _test=Lh1, _matrix=B1 ) +=
        integrate( markedfaces(mesh1,gamma1), idt(u1)*id(nu) );

    B1->close();

    auto F2 = M_backend->newVector( Xh2 );
    form1( _test=Xh2, _vector=F2, _init=true ) =
        integrate( elements(mesh2), f*id(v2) );

    BOOST_FOREACH( int marker, outside2 )
    {
        form1( _test=Xh2, _vector=F2 ) +=
            integrate( markedfaces(mesh2,marker),
                       g*(-grad(v2)*vf::N()+penaldir*id(v2)/hFace()) );
    }

    F2->close();

    auto D2 = M_backend->newMatrix( Xh2, Xh2 );

    form2( _trial=Xh2, _test=Xh2, _matrix=D2, _init=true ) =
        integrate( elements(mesh2), coeff*gradt(u2)*trans(grad(v2)) );

    BOOST_FOREACH( int marker, outside2 )
    {
        form2( _trial=Xh2, _test=Xh2, _matrix=D2 ) +=
            integrate( markedfaces(mesh2,marker),
                       -(gradt(u2)*vf::N())*id(v2)
                       -(grad(v2)*vf::N())*idt(u2)
                       +penaldir*id(v2)*idt(u2)/hFace());
    }

    D2->close();

    auto B2 = M_backend->newMatrix( Xh2, Lh1 );

    Log() << "init_B2 starts\n";
    timers["init_B2"].first.restart();

    form2( _trial=Xh2, _test=Lh1, _matrix=B2, _init=true );

    timers["init_B2"].second = timers["init_B2"].first.elapsed();
    Log() << "init_B2 done in " << timers["init_B2"].second << "s\n";

    form2( _trial=Xh2, _test=Lh1, _matrix=B2 ) +=
        integrate( markedfaces(mesh1,gamma1), -idt(u2)*id(nu) );

    B2->close();

    auto B12 = M_backend->newMatrix( Xh2, Xh1 );

    Log() << "init_B12 starts\n";
    timers["init_B12"].first.restart();

    form2( _trial=Xh2, _test=Xh1, _matrix=B12, _init=true );

    timers["init_B12"].second = timers["init_B12"].first.elapsed();
    Log() << "init_B12 done in " << timers["init_B12"].second << "s\n";

    B12->close();

    auto B21 = M_backend->newMatrix( Xh1, Xh2 );

    Log() << "init_B21 starts\n";
    timers["init_B21"].first.restart();

    form2( _trial=Xh1, _test=Xh2, _matrix=B21, _init=true );

    timers["init_B21"].second = timers["init_B21"].first.elapsed();
    Log() << "init_B21 done in " << timers["init_B21"].second << "s\n";

    B21->close();

    auto FL = M_backend->newVector( Lh1 );

    form1( _test=Lh1, _vector=FL, _init=true );

    FL->close();


    auto BLL = M_backend->newMatrix( Lh1, Lh1 );

    form2( _trial=Lh1, _test=Lh1, _matrix=BLL, _init=true );

    BLL->close();

    auto B1t = M_backend->newMatrix( Lh1, Xh1 );
    Log() << "init_B1t starts\n";
    timers["init_B1t"].first.restart();

    form2( _trial=Lh1, _test=Xh1, _matrix=B1t, _init=true );

    B1->transpose(B1t);

    timers["init_B1t"].second = timers["init_B1t"].first.elapsed();
    Log() << "init_B1t done in " << timers["init_B1t"].second << "s\n";

    auto B2t = M_backend->newMatrix( Lh1, Xh2 );
    Log() << "init_B2t starts\n";
    timers["init_B2t"].first.restart();

    form2( _trial=Lh1, _test=Xh2, _matrix=B2t, _init=true );

    // std::cout <<"arrived\n";
    B2->transpose(B2t);
    // std::cout <<"pass\n";

    timers["init_B2t"].second = timers["init_B2t"].first.elapsed();
    Log() << "init_B2t done in " << timers["init_B2t"].second << "s\n";

    auto myb = Blocks<3,3,double>()<< D1 << B12 << B1t
                                   << B21 << D2 << B2t
                                   << B1 << B2  << BLL ;

    auto AbB = M_backend->newBlockMatrix(myb);
    AbB->close();

    auto FbB = M_backend->newVector( F1->size()+F2->size()+FL->size(),F1->size()+F2->size()+FL->size() );
    auto UbB = M_backend->newVector( F1->size()+F2->size()+FL->size(),F1->size()+F2->size()+FL->size() );

    for (size_type i = 0 ; i < F1->size(); ++ i)
        FbB->set(i, (*F1)(i) );

    for (size_type i = 0 ; i < F2->size(); ++ i)
        FbB->set(F1->size()+i, (*F2)(i) );

    for (size_type i = 0 ; i < FL->size(); ++ i)
        FbB->set(F1->size()+F2->size()+i, (*FL)(i) );

    Log() << "number of dof(u1): " << Xh1->nDof() << "\n";
    Log() << "number of dof(u2): " << Xh2->nDof() << "\n";
    Log() << "number of dof(lambda): " << Lh1->nDof() << "\n";
    Log() << "size of linear system: " << FbB->size() << "\n";

    Log() << "solve starts\n";
    timers["solve"].first.restart();

    M_backend->solve(_matrix=AbB,
                     _solution=UbB,
                     _rhs=FbB,
                     _pcfactormatsolverpackage="umfpack");

    timers["solve"].second = timers["solve"].first.elapsed();
    Log() << "solve done in " << timers["solve"].second << "s\n";

    for (size_type i = 0 ; i < u1.size(); ++ i)
        u1.set(i, (*UbB)(i) );

    for (size_type i = 0 ; i < u2.size(); ++ i)
        u2.set(i, (*UbB)(u1.size()+i) );

    for (size_type i = 0 ; i < mu.size(); ++ i)
        mu.set(i, (*UbB)(u1.size()+u2.size()+i) );

    double L2error12 =integrate(elements(mesh1),
                                (idv(u1)-g)*(idv(u1)-g) ).evaluate()(0,0);
    double L2error1 =   math::sqrt( L2error12 );

    double L2error22 =integrate(elements(mesh2),
                               (idv(u2)-g)*(idv(u2)-g) ).evaluate()(0,0);
    double L2error2 =   math::sqrt( L2error22 );

    double semi_H1error1 =integrate(elements(mesh1),
                                   ( gradv(u1)-gradg )*trans( (gradv(u1)-gradg) ) ).evaluate()(0,0);

    double semi_H1error2 =integrate(elements(mesh2),
                                   ( gradv(u2)-gradg )*trans( (gradv(u2)-gradg) ) ).evaluate()(0,0);

    double H1error1 = math::sqrt( L2error12 + semi_H1error1 );

    double H1error2 = math::sqrt( L2error22 + semi_H1error2 );

    double error =integrate(elements(trace_mesh),
                            (idv(u1)-idv(u2))*(idv(u1)-idv(u2)) ).evaluate()(0,0);

    double global_error = math::sqrt(L2error12 + L2error22 + semi_H1error1 + semi_H1error2);

    std::cout << "----------L2 errors---------- \n" ;
    std::cout << "||u1_error||_L2=" << L2error1 << "\n";
    std::cout << "||u2_error||_L2=" << L2error2 << "\n";
    std::cout << "----------H1 errors---------- \n" ;
    std::cout << "||u1_error||_H1=" << H1error1 << "\n";
    std::cout << "||u2_error||_H1=" << H1error2 << "\n";
    std::cout << "||u_error||_H1=" << global_error << "\n";
    std::cout << "L2 norm of jump at interface  \n" ;
    std::cout << "||u1-u2||_L2=" << math::sqrt(error) << "\n";
    std::cout<<"hsize= " << M_meshSize<< std::endl;
    // this->exportResults(u1,u2,mu);

} // Mortar::run
} // Feel

#endif // __FEELPP_BENCH_MORTAR_HPP






