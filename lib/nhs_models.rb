module NHSModels
  class NHSTable < ActiveRecord::Base
    db_config = File.open(File.dirname(__FILE__) + '/database.yml') { |x| YAML.load(x) }
    establish_connection(db_config[ENV['RAILS_ENV'] || 'development'])
    
    protected
    def convert_hash(hash)
      hash.each do |k, v|
        if v.is_a?(String)
          hash[k] = Iconv.iconv('utf-8', 'latin1', v).join
        end
      end
    end
  end
  
  class DefinicaoProcesso < NHSTable
    set_table_name 'osxdefinicaoprocesso'
    set_primary_key 'bold_id'
    
    has_many :estados,
        :class_name => 'NHSModels::Estado',
        :foreign_key => 'processo'
  end
  
  class Estado < NHSTable
    set_table_name 'osxestado'
    set_primary_key 'bold_id'

    belongs_to :definicao_processo,
        :class_name => 'NHSModels::DefinicaoProcesso',
        :foreign_key => 'processo'
        
    def id
      self.bold_id
    end
  end
  
  class NotaFiscal < NHSTable
    set_table_name 'notafiscal'
    set_primary_key 'bold_id'
    
    belongs_to :estado,
        :class_name => 'NHSModels::Estado',
        :foreign_key => 'situacao'
        
    def get_estado_id(sigla)
      processo = self.estado.definicao_processo
      if estado = processo.estados.to_ary.find { |x| x.sigla == sigla }
        estado.id
      end
    end
  end

  class NotaFiscalView < NHSTable
    set_table_name 'vr_notafiscaleletronica'
    set_primary_key 'notafiscal'
    
    has_many :itens_nota_fiscal,
        :class_name => 'NHSModels::ItemNotaFiscalView',
        :foreign_key => 'notafiscal'
    has_many :duplicatas,
        :class_name => 'NHSModels::DuplicataView',
        :foreign_key => 'notafiscal', :order => 'data_vencimento ASC'
    has_many :notas_referenciadas,
        :class_name => 'NHSModels::NotaFiscalReferenciadaView',
        :foreign_key => 'notafiscal'        
    has_many :volumes,
        :class_name => 'NHSModels::VolumeView',
        :foreign_key => 'notafiscal'        
        
    def id
      self.notafiscal
    end
        
    def values
      result = attributes.clone
      result.symbolize_keys!
      # TODO: remover quando valor_total_ii tiver sido renomeado em nfe.rb
      result[:valor_total_ii] = result[:valor_imposto_importacao]
      
      convert_hash(result)

      result[:items] = self.itens_nota_fiscal.collect { |x| x.nfe_values }
      result[:duplicatas] = self.duplicatas.collect { |x| x.nfe_values }
      result[:notas_referenciadas] = self.notas_referenciadas.collect { |x| x.nfe_values }
      result[:volumes] = self.volumes.collect { |x| x.nfe_values }
      
      result[:items].each_with_index do |item, i|
        item[:numero_item] = i + 1
      end
      
      result
    end

  end
  
  class ItemNotaFiscalView < NHSTable
    set_table_name 'vr_notafiscaleletronicaitem'
    set_primary_key 'notafiscalitem'
    
    has_many :documentos_importacao,
        :class_name => 'NHSModels::DocumentoImportacaoView',
        :foreign_key => 'notafiscalitem'        
    
    def nfe_values
      result = attributes.clone
      result.symbolize_keys!
      
      convert_hash(result)
      
      result[:documentos_importacao] = self.documentos_importacao.collect { |x| x.nfe_values }

      result
    end
  end
  
  class DuplicataView < NHSTable
    set_table_name 'vr_notafiscaleletronicaduplicata'
    set_primary_key 'titulo'
    
    def nfe_values
      result = attributes.clone
      result.symbolize_keys!
      
      # Este módulo gerará o número correto da duplicata após a validação. Antes disso vamos
      # passar um valor dummy para satisfazer o validador
      result[:numero] = '1'

      result
    end
  end
  
  class NotaFiscalReferenciadaView < NHSTable
    set_table_name 'vr_notafiscaleletronicanotareferenciada'
    set_primary_key 'notafiscal'
    
    belongs_to :nota_fiscal,
        :class_name => 'NHSModels::NotaFiscalView',
        :foreign_key => 'notafiscalreferencia'
        
    def nfe_values
      result = { :chave_nfe => nota_fiscal.nfechave.match(/(\d+)/)[1] }
    end
  end
  
  class DocumentoImportacaoView < NHSTable
    set_table_name 'vr_notafiscaleletronicadocumentoimportacao'
    set_primary_key 'documentoimportacao'

    has_many :adicoes,
        :class_name => 'NHSModels::AdicaoDocumentoImportacaoView',
        :foreign_key => 'documentoimportacao'
        
    def nfe_values
      result = attributes.clone
      result.symbolize_keys!

      convert_hash(result)

      result[:adicoes] = self.adicoes.collect { |x| x.nfe_values }
      
      result
    end
  end
  
  class AdicaoDocumentoImportacaoView < NHSTable
    set_table_name 'vr_notafiscaleletronicadocumentoimportacaoadicao'
    set_primary_key 'adicao'
    
    def nfe_values
      result = attributes.clone
      result.symbolize_keys!

      convert_hash(result)

      result
    end
  end
  
  class VolumeView < NHSTable
    set_table_name 'vr_notafiscaleletronicavolumes'
    set_primary_key 'notafiscal'
    
    def nfe_values
      result = attributes.clone
      result.symbolize_keys!

      convert_hash(result)

      result
    end
  end
  
end
