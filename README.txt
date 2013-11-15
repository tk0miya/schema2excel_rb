
�� schema2excel: �f�[�^�x�[�X��`�����������c�[��

schema2excel �̓f�[�^�x�[�X�����`���𒊏o���A
DB ��`�����ۂ����̂𐶐�����c�[���ł��B

MySQL, PostgreSQL, SQL Server �ɑΉ����Ă��܂��B
�� Oracle �͕K�v�ɂȂ�����l���܂��B 
�� MySQL �ȊO�łׂ͍�������m�F��s�����Ă��܂��B
   �K���o�͌��ʂ�ڎ��Ŋm�F���ĉ������B

���p����ۂɂ͈ȉ��̃c�[�����K�v�ł��B

�ERuby 1.8.x
  �Ehttp://rubyforge.org/projects/rubyinstaller/ ����������
  �E1.8.6-26 �ł� rubygems �����삵�Ȃ��̂ŁA1.8.x �n�̍ŐV�ł��g������
  �E1.9.x �n�ł͓��삵�Ȃ��悤�ł�
�EDB �h���C�o
  �E�ȉ��̃R�}���h�ŃC���X�g�[�������
      gem install -r dbi
      gem install -r dbd-mysql
      gem install -r dbd-pg
      gem install -r mysql
  �Edll �f�B���N�g���ɂ���t�@�C���Q�� ruby\bin �f�B���N�g���ɃR�s�[����
    �EWindows �� MySQL Essential 5.x ���璊�o��������
    �EWindows �� PostgreSQL 8.4.x ���璊�o��������
�EGraphviz ���W���[��
  �E�ȉ��̃R�}���h�ŃC���X�g�[�������
      gem install -r ruby-graphviz
�EMS Excel
  �EExcel 2007 �̏ꍇ�͕ʓr OWC �R���|�[�l���g�̓��肪�K�v
  �Ehttp://www.microsoft.com/downloads/details.aspx?FamilyID=7287252C-402E-4F72-97A5-E0FD290D4B76&displaylang=ja

�� �g����

config.yaml ��K���ɕҏW������A�R�}���h�v�����v�g����ȉ������s���ĉ������B

% ruby schema2excel.rb output.xml

�o�͂��ꂽ output.xml ���f�[�^�x�[�X��`���ł��B


�� �d�g��

DBMS �̃e�[�u���R�����g�A�J�����R�����g�𗘗p���Ē�`�𒊏o���Ă��܂��B
���̂��߁A�e�[�u����`�ɃR�����g���܂߂�K�v������܂��B

�� (MySQL):
  CREATE TABLE sample (
    id int(11) NOT NULL auto_increment COMMENT '�v���C�}���L�[',
    body text NOT NULL COMMENT '�{��',
    PRIMARY KEY (id)
  ) COMMENT '�T���v���e�[�u��';

�� (PostgreSQL):
  COMMENT ON TABLE sample IS '�T���v���e�[�u��';
  COMMENT ON COLUMN sample.id IS '�v���C�}���L�[';

