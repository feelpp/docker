;/* -*- mode: c++ -*-

  This file is part of the Feel library

  Author(s): Christophe Prud'homme <christophe.prudhomme@ujf-grenoble.fr>
       Date: 2008-12-10

  Copyright (C) 2008 Universit� Joseph Fourier (Grenoble I)

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
   \file opusmodel.cpp
   \author Christophe Prud'homme <christophe.prudhomme@ujf-grenoble.fr>
   \date 2008-12-10
 */
#if !defined(OPUSMODELRB_IMPL_HPP_)
#define OPUSMODELRB_IMPL_HPP_ 1

#include <feel/feelfilters/gmsh.hpp>
#include <feel/feelfilters/exporter.hpp>
#include <feel/feelvf/vf.hpp>

#include <Eigen/Core>
#include <Eigen/QR>
#include <Eigen/LU>


#include<feel/feelcore/debugeigen.hpp>
#include<opusmodelrb.hpp>
//#include <opusoffline.hpp>
//#include <opusonlines1.hpp>

namespace Feel
{
using namespace Eigen;
using namespace vf;

template<int OrderU, int OrderP, int OrderT>
OpusModelRB<OrderU,OrderP,OrderT>::OpusModelRB( OpusModelRB const& om )
    :
    super( om ),
    M_mesh( om.M_mesh ),
    M_Dmu( new parameterspace_type ),
    M_is_initialized( om.M_is_initialized )
{
    initParametrization();
}
template<int OrderU, int OrderP, int OrderT>
OpusModelRB<OrderU,OrderP,OrderT>::OpusModelRB( po::variables_map const& vm )
    :
    //super( 2, vm ),
    super(vm),
    backend( backend_type::build( vm, "backend.crb.fem" ) ),
    backendM( backend_type::build( vm, "backend.crb.norm" ) ),
    M_meshSize( vm["hsize"].template as<double>() ),
    M_is_steady( vm["steady"].template as<bool>() ),
    M_is_initialized( false ),
    M_mesh( new mesh_type ),
    M_mesh_air( new mesh_type ),
    M_mesh_line( new mesh12_type ),
    M_mesh_cross_section_2( new mesh12_type ),
    M_exporter( Exporter<mesh_type>::New( vm, "opus" ) ),
    M_Dmu( new parameterspace_type )

{

    Log() << "[constructor::vm] constructor, build backend done" << "\n";
    initParametrization();
}
template<int OrderU, int OrderP, int OrderT>
OpusModelRB<OrderU,OrderP,OrderT>::OpusModelRB(  )
    :
    super(),
    backend(),
    backendM(),
    M_meshSize( 1 ),
    M_is_steady( true ),
    M_is_initialized( false ),
    M_mesh( new mesh_type ),
    M_mesh_air( new mesh_type ),
    M_mesh_line( new mesh12_type ),
    M_mesh_cross_section_2( new mesh12_type ),
    M_exporter( Exporter<mesh_type>::New( "ensight", "opus" ) ),
    M_Dmu( new parameterspace_type )

{
    Log() << "[default] constructor, build backend" << "\n";
    backend = backend_type::build( BACKEND_PETSC );
    backendM = backend_type::build( BACKEND_PETSC );
    Log() << "[default] constructor, build backend done" << "\n";
    initParametrization();
    Log() << "[default] init done" << "\n";
}
template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::initParametrization()
{
    parameter_type mu_min( M_Dmu );
    //mu_min << 0.2, 1e-5, 1e6, 0.1, 5e-2;
    mu_min << 0.2, 1e-5, 1e6, 0.1, 4e-3;
    //mu_min << 0.2, 1e-5, 0, 0.1, 4e-3;
    M_Dmu->setMin( mu_min );
    parameter_type mu_max( M_Dmu );
    mu_max << 150, 1e-2, 1e6, 1e2, 5e-2;
    M_Dmu->setMax( mu_max );


    std::cout << "  -- Dmu min : "  << M_Dmu->min() << "\n";
    std::cout << "  -- Dmu max : "  << M_Dmu->max() << "\n";

}
template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::init()
{
    Log() << " -- OpusModelRB::init\n";
    Log() << "   - initialized: " << M_is_initialized << "\n";
    if ( M_is_initialized ) return;
    M_is_initialized = true;

    double e_AIR_ref = 5e-2; // m
#if 0
    typedef Gmsh gmsh_type;
    typedef boost::shared_ptr<gmsh_type> gmsh_ptrtype;

    std::string mesh_name, mesh_desc;
    gmsh_type gmsh;
    gmsh_ptrtype Gmsh_ptrtype;

    //boost::tie( mesh_name, mesh_desc, Gmsh_ptrtype ) = this->data()->createMesh( M_meshSize );
    Gmsh_ptrtype  = this->data()->createMesh( M_meshSize );
    //warning : now mesh_name is empty and fname = .msh
    std::string fname = gmsh.generate( mesh_name, mesh_desc );

    Log() << "Generated mesh thermal\n";
    ImporterGmsh<mesh_type> import( fname );
    M_mesh->accept( import );
    Log() << "Imported mesh thermal\n";

    Gmsh_ptrtype  = this->data()->createMeshLine( 1 );
    fname = gmsh.generate( mesh_name, mesh_desc );
    ImporterGmsh<mesh12_type> import12( fname );
    M_mesh_line->accept( import12 );
    Log() << "Imported mesh line\n";

    Gmsh_ptrtype  = this->data()->createMeshCrossSection2( 0.2 );
    fname = gmsh.generate( mesh_name, mesh_desc );
    ImporterGmsh<mesh12_type> import_cross_section2( fname );
    M_mesh_cross_section_2->accept( import_cross_section2 );
    Log() << "Imported mesh cross section 2\n";
#else
    Log() << "   - Loading mesh thermal h=" << M_meshSize << "\n";
    M_mesh = createGMSHMesh( _mesh=new mesh_type,
                             _desc =  this->data()->createMesh( M_meshSize, true ),
                             _update = MESH_CHECK|MESH_UPDATE_FACES|MESH_UPDATE_EDGES|MESH_RENUMBER );
    Log() << "   - Imported mesh thermal\n";
    M_mesh_line = createGMSHMesh( _mesh=new mesh12_type,
                                 _desc =  this->data()->createMeshLine( 1 ),
                                 _update = MESH_CHECK|MESH_UPDATE_FACES|MESH_UPDATE_EDGES|MESH_RENUMBER );
    Log() << "   - Imported mesh line\n";
    M_mesh_cross_section_2 = createGMSHMesh( _mesh=new mesh12_type,
                                             _desc =  this->data()->createMeshCrossSection2( 0.2 ),
                                             _update = MESH_CHECK|MESH_UPDATE_FACES|MESH_UPDATE_EDGES|MESH_RENUMBER );
    Log() << "   - [init] Imported mesh cross section 2\n";
#endif // 0

    M_P1h = p1_functionspace_type::New( M_mesh_line );
    Log() << "   - P1h built\n";
    M_P0h = p0_space_type::New( M_mesh );
    Log() << "   - P0h built\n";
    typedef typename node<double>::type node_type;
    node_type period(2);
    //period[0]=this->data()->component("PCB").e()+this->data()->component("AIR").e();
    period[0]=this->data()->component("PCB").e()+e_AIR_ref;
    period[1]=0;
    Log() << "   - period built\n";

    M_Th = temp_functionspace_type::New( M_mesh,
                                         MESH_COMPONENTS_DEFAULTS,
                                         Periodic<1,2,value_type>( period ) );
    Log() << "   - Th built\n";
    //M_grad_Th = grad_temp_functionspace_type::New( M_mesh, MESH_COMPONENTS_DEFAULTS );
    //Log() << "grad Th built\n";

    pT = element_ptrtype( new element_type( M_Th ) );
    pV = element_ptrtype( new element_type( M_Th ) );

    M_bdf_poly = element_ptrtype(  new element_type( M_Th ) ) ;

    Log() << "   - pT  built\n";

    Log() << "   - Generated function space\n";
    Log() << "   -  o        number of elements :  " << M_mesh->numElements() << "\n";
    Log() << "   -  o          number of points :  " << M_mesh->numPoints() << "\n";
    Log() << "   -  o number of local dof in Th :  " << M_Th->nLocalDof() << "\n";
    Log() << "   -  o       number of dof in Th :  " << M_Th->nDof() << "\n";
    Log() << "   -  o       number of dof in Th :  " << M_Th->dof()->nDof() << "\n";

    domains = p0_element_ptrtype( new p0_element_type( M_P0h, "domains" ) );
    *domains = vf::project( M_P0h, elements( M_P0h->mesh() ),
                            chi( emarker() == M_Th->mesh()->markerName( "PCB" ) )*M_Th->mesh()->markerName( "PCB" )+
                            chi( emarker() == M_Th->mesh()->markerName( "AIR123" ) )*M_Th->mesh()->markerName( "AIR123" )+
                            chi( emarker() == M_Th->mesh()->markerName( "AIR4" ) )*M_Th->mesh()->markerName( "AIR4" )+
                            chi( emarker() == M_Th->mesh()->markerName( "IC1" ) )*M_Th->mesh()->markerName( "IC1" ) +
                            chi( emarker() == M_Th->mesh()->markerName( "IC2" ) )*M_Th->mesh()->markerName( "IC2" ) );

    k = p0_element_ptrtype( new p0_element_type( M_P0h, "k" ) );
    *k = vf::project( M_P0h, elements( M_P0h->mesh() ),
                      chi( emarker() == M_Th->mesh()->markerName( "PCB" ) )*this->data()->component("PCB").k()+
                      chi( emarker() == M_Th->mesh()->markerName( "AIR123" ) )*this->data()->component("AIR").k()+
                      chi( emarker() == M_Th->mesh()->markerName( "AIR4" ) )*this->data()->component("AIR").k()+
                      chi( emarker() == M_Th->mesh()->markerName( "IC1" ) )*this->data()->component("IC1").k()+
                      chi( emarker() == M_Th->mesh()->markerName( "IC2" ) )*this->data()->component("IC2").k());
    rhoC = p0_element_ptrtype( new p0_element_type( M_P0h, "rhoC" ) );
    *rhoC = vf::project( M_P0h, elements( M_P0h->mesh() ),
                         chi( emarker() == M_Th->mesh()->markerName( "PCB" ) )*this->data()->component("PCB").rhoC()+
                         chi( emarker() == M_Th->mesh()->markerName( "AIR123" ) )*this->data()->component("AIR").rhoC()+
                         chi( emarker() == M_Th->mesh()->markerName( "AIR4" ) )*this->data()->component("AIR").rhoC()+
                         chi( emarker() == M_Th->mesh()->markerName( "IC1" ) )*this->data()->component("IC1").rhoC() +
                         chi( emarker() == M_Th->mesh()->markerName( "IC2" ) )*this->data()->component("IC2").rhoC() );

    Q = p0_element_ptrtype( new p0_element_type( M_P0h, "Q" ) );
    *Q = vf::project( M_P0h, elements( M_P0h->mesh() ),
                      chi( emarker() == M_Th->mesh()->markerName( "IC1" ) )*this->data()->component("IC1").Q()
                      +chi( emarker() == M_Th->mesh()->markerName( "IC2" ) )*this->data()->component("IC2").Q());
    Log() << "   - [OpusModel::OpusModel] P0 functions allocated\n";



    double e_AIR = this->data()->component("AIR").e();

    double e_PCB = this->data()->component("PCB").e();
    double e_IC = this->data()->component("IC1").e();
    //double L_IC = this->data()->component("IC1").h();



    auto chi_AIR = chi( Px() >= e_PCB+e_IC);
    //AUTO( ft, (constant(1.0-math::exp(-M_time/3.0 ) ) ) );
    auto ft = (constant(1.0));
    //AUTO( vy, (constant(3.)/(2.*(e_AIR-e_IC)))*M_flow_rate*(1.-vf::pow((Px()-((e_AIR+e_IC)/2+e_PCB))/((e_AIR-e_IC)/2),2)) );
    auto vy = (constant(3.)/(2.*(e_AIR-e_IC)))*(1.-vf::pow((Px()-((e_AIR+e_IC)/2+e_PCB))/((e_AIR-e_IC)/2),2));
    //double x_mid = e_PCB+(e_IC+e_AIR)/2;
    //AUTO( vy, (constant(3)/(2*e_AIR))*M_flow_rate*(1-vf::pow((Px()-(x_mid))/(e_AIR/2),2))*ft*chi_AIR );
    //auto conv_coeff = vec( constant(0.), vy*ft*chi_AIR );
    auto conv_coeff = vec( constant(0.), vy );


    auto k_AIR = this->data()->component("AIR").k();
    auto detJ44 = (e_AIR - e_IC)/(e_AIR_ref - e_IC);
    auto detJinv44 = (e_AIR_ref - e_IC)/(e_AIR - e_IC);
    auto J44 = mat<2,2>( cst(detJ44), cst(0.), cst(0.), cst(1.));
    auto Jinv44 = mat<2,2>( cst(detJinv44), cst(0.), cst(0.), cst(1.));
    auto K44 = k_AIR * Jinv44;

    //  initialisation de A1 et A2
    M_Aq.resize( Qa() );
    for( int q = 0; q < Qa(); ++q )
    {
        M_Aq[q] = backend->newMatrix( M_Th, M_Th );
    }
    // mass matrix
    M_Mq.resize( Qm() );
    for( int q = 0; q < Qm(); ++q )
    {
        M_Mq[q] = backend->newMatrix( M_Th, M_Th );
    }
    // outputs
    M_L.resize(Nl());
    for( int l = 0; l < Nl(); ++l )
    {
        M_L[l].resize( Ql(l) );
        for( int q = 0; q < Ql(l); ++q )
        {
            M_L[l][q] = backend->newVector( M_Th );
        }
    }


    D = backend->newMatrix( M_Th, M_Th );
    L.resize(Nl());
    for( int l = 0; l < Nl(); ++l )
    {
        L[l] = backend->newVector( M_Th );
    }


    M_temp_bdf = bdf( _space=M_Th, _vm=this->vm(), _name="temperature" , _prefix="temperature" );

    using namespace Feel::vf;

    element_ptrtype bdf_poly ( new element_type ( M_Th ) );

    element_type u( M_Th, "u" );
    element_type v( M_Th, "v" );
    element_type w( M_Th, "w" );

    Log() << "   - Number of dof " << M_Th->nLocalDof() << "\n";

    M_T0 = 300;

    std::vector<std::string> markers;
    markers.push_back( "Gamma_4_AIR1" );
    markers.push_back( "Gamma_4_AIR4" );
    markers.push_back( "Gamma_4_PCB" );

    Log() << "   - Dirichlet T0=" << M_T0 << "\n";
    double surf = integrate( markedelements(M_mesh,"IC2"), constant(1.) ).evaluate()( 0, 0 );
    //
    // output 0

    form1( M_Th, M_L[0][0], _init=true ) =
        integrate( markedelements(M_mesh,"IC1"),
                   id(v) );
    form1( M_Th, M_L[0][0] ) +=
        integrate( markedelements(M_mesh,"IC2"),
                   id(v) );
    M_L[0][0]->close();
    form1( M_Th, M_L[0][1], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR1"),
                   constant(M_T0)*idv(*k)*(-grad(w)*N()+
                                           this->data()->gammaBc()*id(w)/hFace())
            );
    form1( M_Th, M_L[0][1] ) +=
        integrate( markedfaces(M_mesh,"Gamma_4_PCB"),
                   constant(M_T0)*idv(*k)*(-grad(w)*N()+this->data()->gammaBc()*id(w)/hFace())
            );
    M_L[0][1]->close();

    // grad terms in dirichlet condition on AIR4
    // x normal derivative term
    form1( M_Th, M_L[0][2], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   -constant(M_T0)* k_AIR*dx(w)*Nx());
    M_L[0][2]->close();
    // y normal derivative term
    form1( M_Th, M_L[0][3], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   -constant(M_T0)* k_AIR*dy(w)*Ny());
    M_L[0][3]->close();
    // penalisation term in dirichlet constant on AIR4
    form1( M_Th, M_L[0][4], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   M_T0*k_AIR*this->data()->gammaBc()*id(w)/hFace());
    M_L[0][4]->close();
    Log() << "   - rhs 0 done\n";

    // output 1
    form1( M_Th, M_L[1][0], _init=true ) =
        integrate( markedelements(M_mesh,"IC2"),
                   id(v)/surf
            );
    M_L[1][0]->close();
    Log() << "   - rhs 1 done\n";
    // output 2
    // term associated with AIR3 : mult by 1/ea
    form1( M_Th, M_L[2][0], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_3_AIR3"),
                   id(v) );
    M_L[2][0]->close();
    // term associated with AIR4 : mult J44/ea
    form1( M_Th, M_L[2][1], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_3_AIR4"),
                   id(v)
            );
    M_L[2][1]->close();
    Log() << "   - rhs 2 done\n";

    form1( M_Th, M_L[3][0], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_3_AIR3"),
                   id(v) );
    M_L[3][0]->close();
    // term associated with AIR4 : mult J44/ea
    form1( M_Th, M_L[3][1], _init=true ) =
        integrate( markedfaces(M_mesh,"Gamma_3_AIR4"),
                   id(v)
            );
    M_L[3][1]->close();
    Log() << "   - rhs 3 done\n";

    //
    // left hand side terms
    //
    size_type pattern = DOF_PATTERN_COUPLED | DOF_PATTERN_NEIGHBOR;
    // matrix to merge all Aq
    form2( M_Th, M_Th, D, _init=true, _pattern=pattern ) =
        integrate( elements(M_mesh), 0*idt(u)*id(v) )+
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
        this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*
        0.*( leftfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny())+
             rightfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
             leftfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
             rightfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny()) ));
    D->close();
    Log() << "   - D  done\n";

    int AqIndex = 0;
    //test diffusion coeff
    double surfpcb = integrate(markedelements(M_mesh,"PCB"),constant(1.0)).evaluate()( 0, 0 );
    Log() << "   - k_PCB " << this->data()->component("PCB").k() << " " <<
        integrate(markedelements(M_mesh,"PCB"),idv(*k)).evaluate()( 0, 0 )/surfpcb << "\n";

    //
    // Conduction terms
    //
    // PCB + AIR123
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"PCB"),
                   idv(*k)*(gradt(u)*trans(grad(v)) ) );
    form2( M_Th, M_Th, M_Aq[AqIndex] ) +=
        integrate( markedelements(M_mesh,"AIR123"),
                   idv(*k)*(gradt(u)*trans(grad(v)) ) );
    // boundary conditions (diffusion terms)
    form2( M_Th, M_Th, M_Aq[AqIndex] ) +=
        integrate( markedfaces(M_mesh,"Gamma_4_AIR1"),
                   idv(*k)*( -gradt(u)*N()*id(w)
                             -grad(w)*N()*idt(u)
                             +this->data()->gammaBc()*idt(u)*id(w)/hFace() ) );
    form2( M_Th, M_Th, M_Aq[AqIndex] ) +=
        integrate( markedfaces(M_mesh,"Gamma_4_PCB"),
                   idv(*k)*( -gradt(u)*N()*id(w)
                             -grad(w)*N()*idt(u)
                             +this->data()->gammaBc()*idt(u)*id(w)/hFace() ));
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();


    // boundary condition for AIR4 (depends on ea and D)
    // x normal derivative term
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   k_AIR*(-dxt(u)*Nx()*id(w) -dx(w)*Nx()*idt(u) ) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    // y normal derivative term
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   k_AIR*(-dyt(u)*Ny()*id(w) -dy(w)*Ny()*idt(u) ));
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    // penalisation term
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   k_AIR*this->data()->gammaBc()*idt(u)*id(w)/hFace() );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    //
    // IC{1,2} terms
    //
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"IC1" ),
                   (gradt(u)*trans(grad(v)) ));
    form2( M_Th, M_Th, M_Aq[AqIndex] ) +=
        integrate( markedelements(M_mesh,"IC2" ),
                   (gradt(u)*trans(grad(v)) ) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();


    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"AIR4"),
                   k_AIR*dxt(u)*trans(dx(w) ));
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"AIR4"),
                   k_AIR*dyt(u)*trans(dy(w) ));
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    //
    // Convection terms : only y derivative since v=(0,vy) and take vy = 1
    //
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"AIR4"),
                   idv(*rhoC)*dyt(u)*id(w) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"AIR4"),
                   Px()*idv(*rhoC)*dyt(u)*id(w) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedelements(M_mesh,"AIR4"),
                   Px()*Px()*idv(*rhoC)*dyt(u)*id(w) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    Log() << "   - Aq[5]  done\n";
    // no convection AIR123
    //form2( M_Th, M_Th, M_Aq[2] ) +=
    //integrate( markedelements(M_mesh,"AIR123"),
    //idv(*rhoC)*(gradt(u)*(conv_coeff))*id(w) );

    //form2( M_Th, M_Th, M_Aq[2] ) +=
    //integrate( markedfaces(M_mesh,"Gamma_4_AIR1"),
    //idv(*rhoC)*(trans(N())*(conv_coeff))*id(w)*idt(u) );
#if 0
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   idv(*rhoC)*(Ny()*id(w)*idt(u)));
                   //idv(*rhoC)*(trans(N())*(conv_coeff))*id(w)*idt(u) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   Px()*idv(*rhoC)*(Ny()*id(w)*idt(u)));
                   //idv(*rhoC)*(trans(N())*(conv_coeff))*id(w)*idt(u) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_mesh,"Gamma_4_AIR4"),
                   Px()*Px()*idv(*rhoC)*(Ny()*id(w)*idt(u)));
                   //idv(*rhoC)*(trans(N())*(conv_coeff))*id(w)*idt(u) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
#endif
    //
    // Conductance terms
    //
    AUTO(N_IC_PCB,vec(constant(-1.),constant(0.)) );
    Log() << "[add discontinuous interface at boundary " << M_Th->mesh()->markerName( "Gamma_IC1_PCB" ) << "\n";

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces( M_mesh, "Gamma_IC1_PCB" ),
                   (trans(jump(id(w)))*N_IC_PCB)*(trans(jumpt( idt( u ) ))*N_IC_PCB) );
    Log() << "[add discontinuous interface at boundary " << M_Th->mesh()->markerName( "Gamma_IC2_PCB" ) << "\n";
    form2( M_Th, M_Th, M_Aq[AqIndex] ) +=
        integrate( markedfaces( M_mesh, "Gamma_IC2_PCB" ),
                   (trans(jump(id(w)))*N_IC_PCB)*(trans(jumpt( idt( u ) ))*N_IC_PCB) );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();


    // stabilisation terms : AIR4 (in AIR123 velocity is zero)
    // coefficient is Jinv44(1,1) for x terms
    // coefficient is Jinv44(2,2)=1 for y terms

    // x terms
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()) +
                     rightfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()))
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()) +
                     rightfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()))
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*Px()*vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()) +
                     rightfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dx(w)*Nx()))
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();


    // y terms
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(vf::abs(Ny()))*
                   ( leftfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny()) )

            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*vf::abs(Ny()))*
                   ( leftfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny()) )

            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*Px()*vf::abs(Ny()))*
                   ( leftfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dy(w)*Ny()) )

            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    // xy terms
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx())+

                     leftfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx()) )
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();

    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx()) +

                     leftfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx()) )
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();
    form2( M_Th, M_Th, M_Aq[AqIndex], _init=true, _pattern=pattern ) =
        integrate( markedfaces(M_Th->mesh(), M_Th->mesh()->markerName( "AIR4" )),
                   this->data()->gammaTemp()*(vf::pow(hFace(),2.0)/constant(std::pow(OrderT,3.5)))*leftfacev(Px()*Px()*vf::abs(Ny()))*
                   ( leftfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     leftfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     leftfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx()) +

                     leftfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * leftface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * leftface(dx(w)*Nx())+
                     rightfacet(dxt(u)*Nx()) * rightface(dy(w)*Ny())+
                     rightfacet(dyt(u)*Ny()) * rightface(dx(w)*Nx()) )
            );
    Log() << "   - Aq[" << AqIndex << "]  done\n";
    M_Aq[AqIndex++]->close();


    //mas matrix
    form2( M_Th, M_Th, M_Mq[0], _init=true, _pattern=pattern ) =
        integrate ( markedelements(M_mesh,"PCB") ,    idv(rhoC)*idt(u)*id(w) ) +
        integrate ( markedelements(M_mesh,"IC1") ,    idv(rhoC)*idt(u)*id(w) ) +
        integrate ( markedelements(M_mesh,"IC2") ,    idv(rhoC)*idt(u)*id(w) ) +
        integrate ( markedelements(M_mesh,"AIR123") , idv(rhoC)*idt(u)*id(w) ) ;

    form2( M_Th, M_Th, M_Mq[1], _init=true, _pattern=pattern ) =
        integrate ( markedelements(M_mesh,"AIR4") , idv(rhoC)*idt(u)*id(w) ) ;


#if 0
    //
    // H_1 scalar product
    //
    M = backendM->newMatrix( M_Th, M_Th );

    form2( M_Th, M_Th, M, _init=true ) =
        integrate( elements(M_mesh),
                   id(u)*idt(v)
                   +grad(u)*trans(gradt(u))
            );
    M->close();
#endif

    //
    // L_2 scalar product
    //
    M = backendM->newMatrix( M_Th, M_Th );

    form2( M_Th, M_Th, M, _init=true ) =
        integrate( elements(M_mesh),
                   id(u)*idt(v)
            );
    M->close();



    Log() << "   - M  done\n";
    Log() << "OpusModelRB::init done\n";
}

template<int OrderU, int OrderP, int OrderT>
int
OpusModelRB<OrderU,OrderP,OrderT>::Qa() const
{
    //return 17;
    return 20;
}
template<int OrderU, int OrderP, int OrderT>
int
OpusModelRB<OrderU,OrderP,OrderT>::Qm() const
{
    return 2;
}

template<int OrderU, int OrderP, int OrderT>
int
OpusModelRB<OrderU,OrderP,OrderT>::Nl() const
{
    return 4;
}

template<int OrderU, int OrderP, int OrderT>
int
OpusModelRB<OrderU,OrderP,OrderT>::Ql( int l ) const
{
    switch ( l )
    {
    case 1 :
        return 1;
    case 2 :
        return 2;
    case 3 :
        return 2;
    default:
    case 0 :
        return 5;
    }
}

template<int OrderU, int OrderP, int OrderT>
typename OpusModelRB<OrderU,OrderP,OrderT>::theta_vectors_type
OpusModelRB<OrderU,OrderP,OrderT>::computeThetaq( parameter_type const& mu, double time )
{
    //Log() << "[OpusModelRB::computeThetaq] mu = " << mu << "\n";
    double kIC = mu(0);
    double D = mu(1);
    double Q = mu(2);
    double r = mu(3);
    double e_AIR = mu(4);

    double e_AIR_ref = 5e-2; // m
    double e_PCB = this->data()->component("PCB").e();
    double e_IC = this->data()->component("IC1").e();


    double c_1 = 3./(2.*(e_AIR-e_IC));
    double c_2 = (e_AIR-e_IC)/2;
    double c_3 = ((e_AIR+e_IC)/2+e_PCB);
    double TJ = (e_AIR-e_IC)/(e_AIR_ref-e_IC);
    double Tb = (e_AIR_ref-e_AIR)*(e_PCB+e_IC)/(e_AIR_ref-e_IC);

    //auto ft = (constant(1.0));
    double ft = 1.0-math::exp(-time/3);

    //auto vy = (1.-vf::pow((Px()-((e_AIR+e_IC)/2+e_PCB))/((e_AIR-e_IC)/2),2));
    //auto conv_coeff = D*vy;
    double denom = ((e_IC - e_AIR)*(e_IC - e_AIR_ref)*(e_IC - e_AIR_ref));
    double conv1 = 6*(e_PCB + e_AIR_ref)*(e_PCB + e_IC)/denom;
    double conv2 = -  6*(2*e_PCB + e_IC + e_AIR_ref)/denom;
    double conv3 = 6/denom;

    double k_AIR = this->data()->component("AIR").k();
    double detJ44 = (e_AIR - (e_IC))/(e_AIR_ref - (e_IC));
    double detJinv44 = (e_AIR_ref - (e_IC))/(e_AIR - (e_IC));
    double J44xx = detJ44;
    double J44yy = 1.;
    double Jinv44xx = detJinv44;
    double Jinv44yy = 1.;

    //Log() << "detJ44 = " << detJ44 << "\n";
    //Log() << "D= " << D << "\n";
#if 0
    double Dnum = integrate( markedfaces(M_Th->mesh(),M_Th->mesh()->markerName("Gamma_4_AIR4")),
                             -D*(conv1+conv2*Px()+conv3*Px()*Px())*Ny()*detJ44).evaluate()( 0, 0 );
#endif
    //Log() << "Dnum= " << Dnum << "\n";

    int AqIndex = 0;
    M_thetaAq.resize( Qa() );
    M_thetaAq( AqIndex++ ) = 1;
    M_thetaAq( AqIndex++ ) = Jinv44xx*detJ44; //
    M_thetaAq( AqIndex++ ) = Jinv44yy*detJ44; //
    M_thetaAq( AqIndex++ ) = detJ44; //
    M_thetaAq( AqIndex++ ) = kIC; //
    M_thetaAq( AqIndex++ ) = Jinv44xx*Jinv44xx*detJ44; // AIR4  diffusion
    M_thetaAq( AqIndex++ ) = Jinv44yy*Jinv44yy*detJ44; // AIR4  diffusion
    M_thetaAq( AqIndex++ ) = ft*D*conv1*Jinv44yy*detJ44; //
    M_thetaAq( AqIndex++ ) = ft*D*conv2*Jinv44yy*detJ44; //
    M_thetaAq( AqIndex++ ) = ft*D*conv3*Jinv44yy*detJ44; //
    //M_thetaAq( AqIndex++ ) = 0*conv1*detJ44; //
    //M_thetaAq( AqIndex++ ) = 0*conv2*detJ44; //
    //M_thetaAq( AqIndex++ ) = 0*conv3*detJ44; //
    M_thetaAq( AqIndex++ ) = r; //
    M_thetaAq( AqIndex++ ) = ft*D*conv1*Jinv44xx*Jinv44xx*detJ44; // x
    M_thetaAq( AqIndex++ ) = ft*D*conv2*Jinv44xx*Jinv44xx*detJ44; // x
    M_thetaAq( AqIndex++ ) = ft*D*conv3*Jinv44xx*Jinv44xx*detJ44; // x
    M_thetaAq( AqIndex++ ) = ft*D*conv1*Jinv44yy*Jinv44yy*detJ44; // y
    M_thetaAq( AqIndex++ ) = ft*D*conv2*Jinv44yy*Jinv44yy*detJ44; // y
    M_thetaAq( AqIndex++ ) = ft*D*conv3*Jinv44yy*Jinv44yy*detJ44; // y
    M_thetaAq( AqIndex++ ) = ft*D*conv1*Jinv44xx*Jinv44yy*detJ44; // x y
    M_thetaAq( AqIndex++ ) = ft*D*conv2*Jinv44xx*Jinv44yy*detJ44; // x y
    M_thetaAq( AqIndex++ ) = ft*D*conv3*Jinv44xx*Jinv44yy*detJ44; // x y

    //Log() << "ThetaQ = " << M_thetaAq << "\n";
    M_thetaL.resize( Nl() );
    // l = 0
    M_thetaL[0].resize( Ql(0) );
    M_thetaL[0]( 0 ) = Q * (1.0-math::exp(-time)); //
    M_thetaL[0]( 1 ) = 1; // start Dirichlet terms
    M_thetaL[0]( 2 ) = Jinv44xx*detJ44; // ea : dx Nx term dirichlet
    M_thetaL[0]( 3 ) = Jinv44yy*detJ44; // ea : dy Ny term dirichlet
    M_thetaL[0]( 4 ) = detJ44; // ea : penalisation term dirichlet

    //Log() << "ThetaL[0] = " << M_thetaL[0] << "\n";

    // l =1
    M_thetaL[ 1 ].resize( Ql( 1 ) );
    M_thetaL[ 1 ]( 0 ) = 1; //
    //Log() << "ThetaL[1] = " << M_thetaL[1] << "\n";

    // l = 2
    M_thetaL[ 2 ].resize( Ql( 2 ) );
    M_thetaL[ 2 ]( 0 ) = 1./e_AIR;//1/ea; // AIR3
    M_thetaL[ 2 ]( 1 ) = detJ44/e_AIR;//J44/ea; // AIR4
    //Log() << "ThetaL[2] = " << M_thetaL[2] << "\n";

    M_thetaL[ 3 ].resize( Ql( 3 ) );
    M_thetaL[ 3 ]( 0 ) = 1.;
    M_thetaL[ 3 ]( 1 ) = detJ44;
    //Log() << "ThetaL[3] = " << M_thetaL[3] << "\n";


    M_thetaMq.resize( Qm() );
    M_thetaMq( 0 ) = 1 ;
    M_thetaMq( 1 ) = detJ44;

    return boost::make_tuple(M_thetaMq, M_thetaAq, M_thetaL);
}

template<int OrderU, int OrderP, int OrderT>
OpusModelRB<OrderU,OrderP,OrderT>::~OpusModelRB()
{}
template<int OrderU, int OrderP, int OrderT>
typename OpusModelRB<OrderU,OrderP,OrderT>::sparse_matrix_ptrtype
OpusModelRB<OrderU,OrderP,OrderT>::newMatrix() const
{
    auto Dnew = backend->newMatrix( M_Th, M_Th );
    *Dnew  = *D;
    Dnew->zero();
    return Dnew;
}

template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::update( parameter_type const& mu , double time)
{
    this->computeThetaq( mu , time);

    double Fr = mu(1);
    double e_AIR = mu(4);

    double e_AIR_ref = 5e-2; // m
    double e_PCB = this->data()->component("PCB").e();
    double e_IC = this->data()->component("IC1").e();

    double c_1 = 3./(2.*(e_AIR-e_IC));
    double c_2 = (e_AIR-e_IC)/2;
    double c_3 = ((e_AIR+e_IC)/2+e_PCB);
    double TJ = (e_AIR-e_IC)/(e_AIR_ref-e_IC);
    double Tb = (e_AIR_ref-e_AIR)*(e_PCB+e_IC)/(e_AIR_ref-e_IC);

    //auto ft = (constant(1.0));
    double ft = 1.0-math::exp(-time/3);
    //auto vy = (1.-vf::pow((Px()-((e_AIR+e_IC)/2+e_PCB))/((e_AIR-e_IC)/2),2));
    //auto conv_coeff = D*vy;
    double denom = ((e_IC - e_AIR)*(e_IC - e_AIR_ref)*(e_IC - e_AIR_ref));
    double conv1 = 6*(e_PCB + e_AIR_ref)*(e_PCB + e_IC)/denom;
    double conv2 = -  6*(2*e_PCB + e_IC + e_AIR_ref)/denom;
    double conv3 = 6/denom;

    *pV = vf::project( M_Th, markedelements(M_Th->mesh(), M_Th->mesh()->markerName("AIR4") ),
                       ft*Fr*(conv1+conv2*Px()+conv3*Px()*Px()) );
    Log() << "[update(mu)] pV done\n";
    boost::timer ti;
    D->zero();
    for( size_type q = 0;q < M_Aq.size(); ++q )
    {
        //Log() << "[affine decomp] scale q=" << q << " with " << M_thetaAq(q) << "\n";
        D->addMatrix( M_thetaAq(q) , M_Aq[q] );
    }

    Log() << "[update(mu,"<<time<<")] D assembled in " << ti.elapsed() << "s\n";ti.restart();
    for( int l = 0; l < Nl(); ++l )
    {
        L[l]->zero();
        for( size_type q = 0;q < M_L[l].size(); ++q )
        {
            //Log() << "[affine decomp] output " << l << " term " << q << "=" << M_thetaL[l](q) << "\n";
            L[l]->add( M_thetaL[l]( q ) , M_L[l][q] );
        }
        Log() << "[update(mu,"<<time<<")] L[" << l << "] assembled in " << ti.elapsed() << "s\n";ti.restart();
    }

    //mass matrix contribution
    auto vec_bdf_poly = backend->newVector( M_Th );
    for( size_type q = 0;q < M_Mq.size(); ++q )
    {
        //left hand side
        D->addMatrix( M_thetaMq[q]*M_bdf_coeff, M_Mq[q] );
        //right hand side
        *vec_bdf_poly = *M_bdf_poly;
        vec_bdf_poly->scale( M_thetaMq[q]);
        L[0]->addVector( *vec_bdf_poly, *M_Mq[q]);
    }
    Log() << "[update(mu,"<<time<<")] add mass matrix contributions in " << ti.elapsed() << "s\n";ti.restart();

    M->zero();
    for( size_type q = 0;q < M_Mq.size(); ++q )
    {
        M->addMatrix( M_thetaMq(q) , M_Mq[q] );
    }

}
template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::solve( parameter_type const& mu )
{
    element_ptrtype T( new element_type( M_Th ) );


    this->solve( mu, T );
    //this->exportResults( *T );

    std::vector<double> LT( this->Nl() );
    for( int l = 0;l < this->Nl()-1; ++l)
    {
        LT[l] = inner_product( *L[l], *T );
        Log() << "LT(" << l << ")=" << LT[l] << "\n";
    }
    LT[3] = inner_product( *L[3], *pV );
    Log() << "LT(" << 3 << ")=" << LT[3] << "\n";

}
template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::solve( parameter_type const& mu, element_ptrtype& T )
{
    boost::timer ti;
    //Log() << "solve(mu,T) for parameter " << mu << "\n";
    using namespace Feel::vf;


    //initialization of temperature
    *T = vf::project( M_Th, elements( M_Th->mesh() ), constant( M_T0 ) );
    M_temp_bdf->initialize(*T);


    if ( M_is_steady )
    {
        M_temp_bdf->setSteady();
    }

    M_temp_bdf->start();
    M_bdf_coeff = M_temp_bdf->polyDerivCoefficient(0);

    for( M_temp_bdf->start(); !M_temp_bdf->isFinished(); M_temp_bdf->next() )
    {
        *M_bdf_poly = M_temp_bdf->polyDeriv();
        this->update( mu , M_temp_bdf->time() );
        Log() << "[solve(mu)] : time = "<<M_temp_bdf->time()<<"\n";
        Log() << "[solve(mu)] update(mu) done in " << ti.elapsed() << "s\n";ti.restart();
        Log() << "[solve(mu)] start solve\n";
        //backend->solve( _matrix=D,  _solution=*T, _rhs=L[0], _prec=D );
        auto ret = backend->solve( _matrix=D,  _solution=*T, _rhs=L[0], _reuse_prec=(M_temp_bdf->iteration() >=2));

        if ( !ret.get<0>() )
        {
            Log()<<"WARNING : we have not converged ( nb_it : "<<ret.get<1>()<<" and residual : "<<ret.get<2>() <<" ) \n";
        }

        Log() << "[solve(mu)] solve done in " << ti.elapsed() << "s\n";ti.restart();
        this->exportResults(M_temp_bdf->time(), *T );
        Log() << "[solve(mu)] export done in " << ti.elapsed() << "s\n";ti.restart();

        M_temp_bdf->shiftRight(*T);

    }


}

template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::solve( parameter_type const& mu, element_ptrtype& T, vector_ptrtype const& rhs, bool transpose )
{
    //Log() << "solve(mu,T) for parameter " << mu << "\n";
    using namespace Feel::vf;


    *T = vf::project( M_Th, elements( M_Th->mesh() ), constant( M_T0 ) );
    M_temp_bdf->initialize(*T);


    if ( M_is_steady )
    {
        M_temp_bdf->setSteady();
    }

    M_temp_bdf->start();
    M_bdf_coeff = M_temp_bdf->polyDerivCoefficient(0);
    for( M_temp_bdf->start(); !M_temp_bdf->isFinished(); M_temp_bdf->next() )
    {
        *M_bdf_poly = M_temp_bdf->polyDeriv();
        this->update( mu , M_temp_bdf->time() );
        if( transpose )
        {
            auto ret = backend->solve( _matrix=D->transpose(),  _solution=*T, _rhs=rhs , _reuse_prec=(M_temp_bdf->iteration() >=2));
            if ( !ret.get<0>() )
            {
                Log()<<"WARNING : we have not converged ( nb_it : "<<ret.get<1>()<<" and residual : "<<ret.get<2>() <<" ) \n";
            }

        }
        else
        {
            auto ret = backend->solve( _matrix=D,  _solution=*T, _rhs=rhs , _reuse_prec=(M_temp_bdf->iteration() >=2));
            if ( !ret.get<0>() )
            {
                Log()<<"WARNING : we have not converged ( nb_it : "<<ret.get<1>()<<" and residual : "<<ret.get<2>() <<" ) \n";
            }
        }
        this->exportResults(M_temp_bdf->time(), *T );


        M_temp_bdf->shiftRight(*T);
    }




}

template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::l2solve( vector_ptrtype& u, vector_ptrtype const& f )
{
    //Log() << "l2solve(u,f)\n";
    //backendM->solve( _matrix=M,  _solution=u, _rhs=f, _prec=M );
    //backendM = backend_type::build( BACKEND_PETSC );
    backendM->solve( _matrix=M, _solution=u, _rhs=f );
    //Log() << "l2solve(u,f) done\n";
}

template<int OrderU, int OrderP, int OrderT>
double
OpusModelRB<OrderU,OrderP,OrderT>::scalarProduct( vector_ptrtype const& x, vector_ptrtype const& y )
{
    return M->energy( x, y );
}
template<int OrderU, int OrderP, int OrderT>
double
OpusModelRB<OrderU,OrderP,OrderT>::scalarProduct( vector_type const& x, vector_type const& y )
{
    return M->energy( x, y );

}
template<int OrderU, int OrderP, int OrderT>
double
OpusModelRB<OrderU,OrderP,OrderT>::output( int output_index, parameter_type const& mu )
{
    this->solve( mu, pT );
    vector_ptrtype U( backend->newVector( M_Th ) );
    *U = *pT;
    Log() << "S1 = " << inner_product( *L[1], *U ) << "\n S2 = " << inner_product( *L[2], *U ) << "\n";
    return inner_product( L[output_index], U );
}

template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::run( const double * X, unsigned long N, double * Y, unsigned long P )
{
    Log() << "[OpusModel::run] input/output relationship\n";

    parameter_type mu( M_Dmu );

    mu << /*kIC*/X[0],/*D*/X[1], /*Q*/X[2], /*r*/X[3], /*ea*/X[4];

#if 0
    M_is_steady = X[0];
    if( M_is_steady )
    {
       mu << /*kIC*/X[1],/*D*/X[2], /*Q*/X[3], /*r*/X[4], /*ea*/X[5];
    }
    else
   {
       mu << /*kIC*/X[1],/*D*/X[2], /*Q*/X[3], /*r*/X[4], /*ea*/X[5], /*dt*/X[6], /*Tf*/X[7];
   }
#endif

    for( int i = 0;i < N; ++i )
        Log() << "[OpusModelRB::run] X[" << i << "]=" << X[i] << "\n";

    this->data()->component("IC1").setK( X[0] );
    this->data()->component("IC2").setK( X[0] );
    this->data()->component("AIR").setFlowRate( X[1] );
    this->data()->component("IC1").setQ( X[2] );
    this->data()->component("IC2").setQ( X[2] );

    for( int i = 0;i < N; ++i )
        Log() << "[OpusModel::run] X[" << i << "]=" << X[i] << "\n";
    this->data()->component("AIR").setE( X[4] );
    M_meshSize = X[5];
    Log() << "[OpusModelRB::run] parameters set\n";

    this->data()->print();

    Log() << "[OpusModelRB::run] parameters print done\n";

    Log() << "[OpusModelRB::run] init\n";
    this->init();
    Log() << "[OpusModelRB::run] init done\n";

    *pT = vf::project( M_Th, elements( M_Th->mesh() ), constant( M_T0 ) );
    M_temp_bdf->initialize(*pT);


    this->solve( mu, pT );
    Log() << "[OpusModelRB::run] solve done\n";

    vector_ptrtype U( backend->newVector( M_Th ) );
    *U = *pT;
    Y[0] = inner_product( *L[1], *U );
    Y[1] = inner_product( *L[2], *U );
    Log() << "[OpusModel::run] run done, set outputs\n";
    for( int i = 0;i < P; ++i )
        Log() << "[OpusModel::run] Y[" << i << "]=" << Y[i] << "\n";

}
template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::run()
{}

template<int OrderU, int OrderP, int OrderT>
void
OpusModelRB<OrderU,OrderP,OrderT>::exportResults(double time, temp_element_type& T )
{
    std::ostringstream osstr ;


    int j = time;
    osstr<<j;
    //Log() << "exportresults : " << this->data()->doExport() << "\n";
    //if ( this->data()->doExport() )
    {
        Log() << "exporting...\n";
        M_exporter->step(0)->setMesh( T.functionSpace()->mesh() );
        M_exporter->step(0)->add( "Domains", *domains );
        M_exporter->step(0)->add( "k", *k);
        M_exporter->step(0)->add( "rhoC", *rhoC );
        M_exporter->step(0)->add( "Q", *Q );
        M_exporter->step(0)->add( "T", T );
        M_exporter->step(0)->add( "V", *pV );
        //M_exporter->step(0)->add( "Velocity",  U.template element<0>() );
        //M_exporter->step(0)->add( "Pressure",  U.template element<1>() );

        using namespace  vf;
        //typename grad_temp_functionspace_type::element_type g( M_grad_Th, "k*grad(T)" );
        //g = vf::project( M_grad_Th, elements( M_grad_Th->mesh() ), trans(idv(*k)*gradv(T)) );
        //M_exporter->step(0)->add( "k_grad(T)", g );
        M_exporter->save();
        Log() << "exporting done.\n";
    }
}

} // Feel

#endif
