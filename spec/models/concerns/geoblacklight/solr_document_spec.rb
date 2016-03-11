require 'spec_helper'

describe Geoblacklight::SolrDocument do
  let(:document) { SolrDocument.new(document_attributes) }
  describe '#available?' do
    let(:document_attributes) { {} }
    describe 'a public document' do
      it 'alwayses be available' do
        allow(document).to receive('same_institution?').and_return(false)
        allow(document).to receive('public?').and_return(true)
        expect(document.available?).to be_truthy
      end
    end
    describe 'a restricted document' do
      it 'onlies be available if from same institution' do
        allow(document).to receive('same_institution?').and_return(true)
        allow(document).to receive('public?').and_return(false)
        expect(document.available?).to be_truthy
      end
    end
  end
  describe '#public?' do
    describe 'a public document' do
      let(:document_attributes) { { dc_rights_s: 'PUBLIC' } }
      it 'is public' do
        expect(document.public?).to be_truthy
      end
    end
    describe 'a restricted resource' do
      let(:document_attributes) { { dc_rights_s: 'RESTRICTED' } }
      it 'does not be public' do
        expect(document.public?).to be_falsey
      end
    end
  end
  describe '#downloadable?' do
    describe 'available direct download' do
      let(:document_attributes) do
        {
          dc_rights_s: 'Public',
          dct_references_s: {
            'http://schema.org/downloadUrl' => 'http://example.com/direct/data.zip'
          }.to_json
        }
      end
      it 'will be downloadable' do
        expect(document.downloadable?).to be_truthy
      end
    end
  end
  describe '#same_institution?' do
    describe 'within the same institution' do
      let(:document_attributes) { { dct_provenance_s: 'STANFORD' } }
      it 'is true' do
        allow(Settings).to receive('Institution').and_return('Stanford')
        expect(document.same_institution?).to be_truthy
      end
      it 'matches case inconsistencies' do
        allow(Settings).to receive('Institution').and_return('StAnFord')
        expect(document.same_institution?).to be_truthy
      end
    end
    describe 'within a different institution' do
      let(:document_attributes) { { dct_provenance_s: 'MIT' } }
      it 'is false' do
        allow(Settings).to receive('Institution').and_return('Stanford')
        expect(document.same_institution?).to be_falsey
      end
    end
  end
  describe 'references' do
    let(:document_attributes) { {} }
    it 'generates a new references object' do
      expect(document.references).to be_an Geoblacklight::References
    end
  end
  describe 'download_types' do
    let(:document_attributes) { {} }
    it 'calls download_types' do
      expect_any_instance_of(Geoblacklight::References).to receive(:download_types)
      document.download_types
    end
  end
  describe 'direct_download' do
    let(:document_attributes) { {} }
    describe 'with a direct download' do
      let(:document_attributes) do
        {
          dct_references_s: {
            'http://schema.org/downloadUrl' => 'http://example.com/urn:hul.harvard.edu:HARVARD.SDE2.TG10USAIANNH/data.zip'
          }.to_json
        }
      end
      it 'returns a direct download hash' do
        expect_any_instance_of(Geoblacklight::Reference).to receive(:to_hash)
        document.direct_download
      end
    end
    it 'returns nil if no direct download' do
      expect_any_instance_of(Geoblacklight::Reference).to_not receive(:to_hash)
      expect(document.direct_download).to be_nil
    end
  end
  describe 'hgl_download' do
    describe 'with an hgl download' do
      let(:document_attributes) do
        {
          dct_references_s: {
            'http://schema.org/DownloadAction' => 'http://example.com/harvard'
          }.to_json
        }
      end
      it 'returns an hgl download hash' do
        expect(document.hgl_download[:hgl]).to eq('http://example.com/harvard')
      end
    end
    describe 'without an hgl download' do
      let(:document_attributes) { {} }
      it 'returns nil' do
        expect(document.direct_download).to be_nil
      end
    end
  end
  describe 'iiif_download' do
    describe 'with a IIIF download' do
      let(:document_attributes) do
        {
          dct_references_s: {
            'http://iiif.io/api/image' => 'https://example.edu/images/info.json'
          }.to_json
        }
      end
      it 'returns a IIIF download hash' do
        expect(document.iiif_download[:iiif]).to eq('https://example.edu/images/info.json')
      end
    end
    describe 'without a IIIF download' do
      let(:document_attributes) { {} }
      it 'returns nil' do
        expect(document.iiif_download).to be_nil
      end
    end
  end
  describe 'item_viewer' do
    let(:document_attributes) { {} }
    it 'is a ItemViewer' do
      expect(document.item_viewer).to be_an Geoblacklight::ItemViewer
    end
  end
  describe 'viewer_protocol' do
    describe 'with a wms reference' do
      let(:document_attributes) do
        {
          dct_references_s: {
            'http://www.opengis.net/def/serviceType/ogc/wms' => 'http://www.example.com/wms'
          }.to_json
        }
      end
      it 'returns wms protocol' do
        expect(document.viewer_protocol).to eq 'wms'
      end
    end
    let(:document_attributes) { {} }
    it 'returns leaflet protocol' do
      expect(document.viewer_protocol).to eq 'map'
    end
  end
  describe 'viewer_endpoint' do
    describe 'with a wms reference' do
      let(:document_attributes) do
        {
          dct_references_s: {
            'http://www.opengis.net/def/serviceType/ogc/wms' => 'http://www.example.com/wms'
          }.to_json
        }
      end
      it 'returns wms endpoint' do
        expect(document.viewer_endpoint).to eq 'http://www.example.com/wms'
      end
    end
    let(:document_attributes) { {} }
    it 'returns no endpoint' do
      expect(document.viewer_endpoint).to eq ''
    end
  end
  describe 'checked_endpoint' do
    let(:document_attributes) { {} }
    let(:reference) { Geoblacklight::Reference.new(['http://www.opengis.net/def/serviceType/ogc/wms', 'http://www.example.com/wms']) }
    it 'returns endpoint if available' do
      expect_any_instance_of(Geoblacklight::References).to receive(:wms).and_return(reference)
      expect(document.checked_endpoint('wms')).to eq 'http://www.example.com/wms'
    end
    it 'return nil if not available' do
      expect_any_instance_of(Geoblacklight::References).to receive(:wms).and_return(nil)
      expect(document.checked_endpoint('wms')).to be_nil
    end
  end
  describe 'method_missing' do
    let(:document_attributes) { {} }
    it 'calls checked_endpoint with parsed method name if matches' do
      expect(document).to receive(:checked_endpoint).with('wms').and_return(nil)
      expect(document.wms_url).to be_nil
    end
    it 'raises no method error' do
      expect { document.wms_urlz }.to raise_error NoMethodError
    end
  end
end