/* -*- mode: c++; coding: utf-8; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4; show-trailing-whitespace: t  -*-
 
 This file is part of the Feel++ library
 
 Author(s): Christophe Prud'homme <christophe.prudhomme@feelpp.org>
 Date: 16 Mar 2015
 
 Copyright (C) 2015 Feel++ Consortium
 
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
#include <iostream>
#include <boost/property_tree/json_parser.hpp>
#include <feel/feelcore/feel.hpp>
#include <feel/feelcore/environment.hpp>

#include <feel/feelmodels/modelmaterials.hpp>

namespace Feel {

ModelMaterial::ModelMaterial( WorldComm const& worldComm )
    :
    M_worldComm( &worldComm )
{}
ModelMaterial::ModelMaterial( std::string const& name, pt::ptree const& p, WorldComm const& worldComm, std::string const& directoryLibExpr )
    :
    M_worldComm( &worldComm ),
    M_name( name ),
    M_p( p ),
    M_directoryLibExpr( directoryLibExpr )
{
    if( boost::optional<std::string> itphyisic = p.get_optional<std::string>( "physics" ) )
        M_physics = *itphyisic;

    std::set<std::string> matProperties = { "rho","mu","Cp","Cv","Tref","beta",
                                            "k11","k12","k13","k22","k23","k33",
                                            "E","nu","sigma","C","Cs","Cl","L",
                                            "Ks","Kl","Tsol","Tliq" };
    for ( std::string const& prop : matProperties )
        this->setProperty( prop,M_p );
}

bool
ModelMaterial::hasPropertyConstant( std::string const& prop ) const
{
    auto itFindProp = M_materialProperties.find( prop );
    if ( itFindProp == M_materialProperties.end() )
        return false;
    auto const& matProp = itFindProp->second;
    if ( !std::get<0>( matProp ) )
        return false;
    return true;
}
bool
ModelMaterial::hasPropertyExprScalar( std::string const& prop ) const
{
    auto itFindProp = M_materialProperties.find( prop );
    if ( itFindProp == M_materialProperties.end() )
        return false;
    auto const& matProp = itFindProp->second;
    if ( !std::get<1>( matProp ) )
        return false;
    return true;
}
bool
ModelMaterial::hasPropertyExprVectorial2( std::string const& prop ) const
{
    auto itFindProp = M_materialProperties.find( prop );
    if ( itFindProp == M_materialProperties.end() )
        return false;
    auto const& matProp = itFindProp->second;
    if ( !std::get<2>( matProp ) )
        return false;
    return true;
}
bool
ModelMaterial::hasPropertyExprVectorial3( std::string const& prop ) const
{
    auto itFindProp = M_materialProperties.find( prop );
    if ( itFindProp == M_materialProperties.end() )
        return false;
    auto const& matProp = itFindProp->second;
    if ( !std::get<3>( matProp ) )
        return false;
    return true;
}
double
ModelMaterial::propertyConstant( std::string const& prop ) const
{
    if ( this->hasPropertyConstant( prop ) )
        return *std::get<0>( M_materialProperties.find( prop )->second );
    else
        return 0;
}
ModelMaterial::expr_scalar_type const&
ModelMaterial::propertyExprScalar( std::string const& prop ) const
{
    CHECK( this->hasPropertyExprScalar( prop ) ) << "no scalar expr";
    return *std::get<1>( M_materialProperties.find( prop )->second );
}
ModelMaterial::expr_vectorial2_type const&
ModelMaterial::propertyExprVectorial2( std::string const& prop ) const
{
    CHECK( this->hasPropertyExprVectorial2( prop ) ) << "no vectorial2 expr";
    return *std::get<2>( M_materialProperties.find( prop )->second );
}
ModelMaterial::expr_vectorial3_type const&
ModelMaterial::propertyExprVectorial3( std::string const& prop ) const
{
    CHECK( this->hasPropertyExprVectorial3( prop ) ) << "no vectorial3 expr";
    return *std::get<3>( M_materialProperties.find( prop )->second );
}

void
ModelMaterial::setProperty( std::string const& property, double val )
{
    M_materialProperties[property] = mat_property_expr_type();
    std::get<0>( M_materialProperties[property] ) = val;
}

void
ModelMaterial::setProperty( std::string const& property, pt::ptree const& p )
{
    if( boost::optional<double> itvald = p.get_optional<double>( property ) )
    {
        double val = *itvald;
        VLOG(1) << "set property " << property << " is constant : " << val;
        M_materialProperties[property] = mat_property_expr_type();
        std::get<0>( M_materialProperties[property] ) = val;
    }
    else if( boost::optional<std::string> itvals = p.get_optional<std::string>( property ) )
    {
        std::string feelExprString = *itvals;
        auto parseExpr = GiNaC::parse( feelExprString );
        auto const& exprSymbols = parseExpr.second;
        auto ginacEvalm = parseExpr.first.evalm();

        bool isLst = GiNaC::is_a<GiNaC::lst>( ginacEvalm );
        int nComp = 1;
        if ( isLst )
            nComp = ginacEvalm.nops();

        if ( nComp == 1 && ( exprSymbols.empty() || ( exprSymbols.size() == 1 && exprSymbols[0].get_name() == "0" ) ) )
        {
            std::string stringCstExpr = ( isLst )? str( ginacEvalm.op(0) ) :str( ginacEvalm );
            double val = 0;
            try
            {
                val = std::stod( stringCstExpr );
            }
            catch (std::invalid_argument& err)
            {
                CHECK( false ) << "cast fail from expr to double\n";
            }
            VLOG(1) << "set property " << property <<" is const from expr=" << val;
            M_materialProperties[property] = mat_property_expr_type();
            std::get<0>(M_materialProperties[property]) = val;
        }
        else
        {
            VLOG(1) << "set property " << property << " build symbolic expr with nComp=" << nComp;
            M_materialProperties[property] = mat_property_expr_type();
            if ( nComp == 1 )
                std::get<1>( M_materialProperties[property] ) = boost::optional<expr_scalar_type>( expr<expr_order>( feelExprString,"",*M_worldComm,M_directoryLibExpr ) );
            else if ( nComp == 2 )
                std::get<2>( M_materialProperties[property] ) = boost::optional<expr_vectorial2_type>( expr<2,1,expr_order>( feelExprString,"",*M_worldComm,M_directoryLibExpr ) );
            else if ( nComp == 3 )
                std::get<3>( M_materialProperties[property] ) = boost::optional<expr_vectorial3_type>( expr<3,1,expr_order>( feelExprString,"",*M_worldComm,M_directoryLibExpr ) );

        }
    }
}

void
ModelMaterial::setParameterValues( std::map<std::string,double> const& mp )
{
    for ( auto & matPropPair : M_materialProperties )
    {
        std::string const& matPropName = matPropPair.first;
        if ( this->hasPropertyExprScalar( matPropName ) )
            std::get<1>( matPropPair.second )->setParameterValues( mp );
        if ( this->hasPropertyExprVectorial2( matPropName ) )
            std::get<2>( matPropPair.second )->setParameterValues( mp );
        if ( this->hasPropertyExprVectorial3( matPropName ) )
            std::get<3>( matPropPair.second )->setParameterValues( mp );
    }
}


std::ostream& operator<<( std::ostream& os, ModelMaterial const& m )
{
    os << "Material " << m.name()
       << "[ rho: " << m.rho()
       << ", mu: " << m.mu()
       << ", Cp: " << m.Cp()
       << ", Cv: " << m.Cv()
       << ", Tref: " << m.Tref()
       << ", beta: " << m.beta()
       << ", k11: " << m.k11()
       << ", k12: " << m.k12()
       << ", k13: " << m.k13()
       << ", k22: " << m.k22()
       << ", k23: " << m.k23()
       << ", k33: " << m.k33()
       << ", E: " << m.E()
       << ", nu: " << m.nu()
       << ", sigma: " << m.sigma()
       << ", Cs: " <<  m.Cs()
       << ", Cl: " <<  m.Cl()
       << ", L: " <<  m.L()
       << ", Ks: " <<  m.Ks()
       << ", Kl: " <<  m.Kl()
       << ", Tsol: " <<  m.Tsol()
       << ", Tliq: " <<  m.Tliq()
       << "]";
    return os;
}

ModelMaterials::ModelMaterials( WorldComm const& worldComm )
    :
    M_worldComm( &worldComm )
{}

ModelMaterials::ModelMaterials( pt::ptree const& p, WorldComm const& worldComm )
    :
    M_worldComm( &worldComm ),
    M_p( p )
{
    setup();
}

ModelMaterial
ModelMaterials::loadMaterial( std::string const& s )
{
    pt::ptree p;
    pt::read_json( s, p );
    return this->getMaterial( p );
}
void
ModelMaterials::setup()
{
    for( auto const& v : M_p )
    {
        LOG(INFO) << "Material Physical/Region :" << v.first  << "\n";
        if ( auto fname = v.second.get_optional<std::string>("filename") )
        {
            LOG(INFO) << "  - filename = " << Environment::expand( fname.get() ) << std::endl;
            this->insert( std::make_pair( v.first, this->loadMaterial( Environment::expand( fname.get() ) ) ) );
        }
        else
        {
            this->insert( std::make_pair( v.first, this->getMaterial( v.second ) ) );
        }
    }
}
ModelMaterial
ModelMaterials::getMaterial( pt::ptree const& v )
{
    std::string t = v.get<std::string>( "name" );
    LOG(INFO) << "loading material name: " << t << std::endl;
    ModelMaterial m( t, v, *M_worldComm, M_directoryLibExpr );
    LOG(INFO) << "adding material " << m;
    return m;
}

void
ModelMaterials::setParameterValues( std::map<std::string,double> const& mp )
{
    for( auto & mat : *this )
        mat.second.setParameterValues( mp );
}

void
ModelMaterials::saveMD(std::ostream &os)
{
  os << "### Materials\n";
  os << "|Material Physical Region Name|Rho|mu|Cp|Cv|k11|k12|k13|k22|k23|k33|Tref|beta|C|YoungModulus|nu|Sigma|Cs|Cl|L|Ks|Kl|Tsol|Tliq|\n";
  os << "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n";
  for(auto it = this->begin(); it!= this->end(); it++ )
    os << "|" << it->first
       << "|" << it->second.name()
       << "|" << it->second.rho()
       << "|" << it->second.mu()
       << "|" << it->second.Cp()
       << "|" << it->second.Cv()
       << "|" << it->second.Tref()
       << "|" << it->second.beta()
       << "|" << it->second.k11()
       << "|" << it->second.k12()
       << "|" << it->second.k13()
       << "|" << it->second.k22()
       << "|" << it->second.k23()
       << "|" << it->second.k33()
       << "|" << it->second.E()
       << "|" << it->second.nu()
       << "|" << it->second.sigma()
       << "|" << it->second.Cs()
       << "|" << it->second.Cl()
       << "|" << it->second.L()
       << "|" << it->second.Ks()
       << "|" << it->second.Kl()
       << "|" << it->second.Tsol()
       << "|" << it->second.Tliq()
       << "|\n";
  os << "\n";
}

}

