require 'iconv'
require 'socket'

module NFeIntegrator

  def self.find_nota_fiscal(nf_id)
    if nf = NHSModels::NotaFiscalView.find(:first, :conditions => ['notafiscal = ?', nf_id])
      nf.values
    end
  end
  
  def self.after_xml_construction(nf_xml)
    prefixo = nf_xml.serie.to_i >= 900 ? 'C' : 'N'
    num_nf = nf_xml.numero.to_i
    nf_xml.duplicatas.each_with_index do |dup, i|
      dup.numero = "%s%06d-%d" % [prefixo, num_nf, i + 1]
    end
  end

  def self.notify_progress(source_obj)

  end

  def self.notify_completion(nf_id, source_obj)
    nf = NHSModels::NotaFiscal.find(nf_id.to_i)
    
    if ConsultaNotaFiscal === source_obj
      source_obj = source_obj.nota_fiscal
    end

    if source_obj.codigo_status_efetivo == '100'
      # Os .to_s são para converter nil em brancos
      nf.update_attributes!(
          'situacao' => nf.get_estado_id('autorizada'),
          'nfechave' => source_obj.chave.to_s,
          'serie' => source_obj.serie.to_s,
          'numero' => "%06d" % source_obj.numero.to_i,
          'nfecodigoretorno' => source_obj.codigo_status_efetivo.to_s,
          'nfemsgretorno' => conv(source_obj.mensagem_status_efetiva.to_s),
          'nfeestadoprocessamento' => '')
    elsif source_obj.codigo_status_efetivo == '101'
      nf.update_attributes!(
          'situacao' => nf.get_estado_id('autorizada_cancelamento'),
          'nfecodigoretorno' => source_obj.codigo_status_efetivo.to_s,
          'nfemsgretorno' => conv(source_obj.mensagem_status_efetiva.to_s),
          'nfeestadoprocessamento' => '')
    else
      operacao = source_obj.respond_to?(:nota_fiscal) ? "cancelamento" : "autorizacao"
      nf.update_attributes!(
          'situacao' => nf.get_estado_id("erro_#{operacao}"),
          'nfecodigoretorno' => source_obj.codigo_status_efetivo.to_s,
          'nfemsgretorno' => conv(source_obj.mensagem_status_efetiva.to_s),
          'nfeestadoprocessamento' => '')
    end
    
    notify_bold(nf_id)
  end

  private
  def self.conv(msg)
    Iconv.iconv('latin1', 'utf-8', msg).join
  end
  
  def self.notify_bold(object_id)
    bold_config = File.open(File.dirname(__FILE__) + '/bold.yml') { |x| YAML.load(x) }
    current = bold_config[ENV['RAILS_ENV'] || 'development']
    
    socket = TCPSocket.new(current['host'], Integer(current['port']))
    begin
      guid = current['client_guid']
      socket.write("TransmitEvents #{guid} E:#{object_id}\n")
      socket.write("Remove #{guid}\n")
    ensure
      socket.close
    end
  end

end
